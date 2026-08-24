from fastapi import APIRouter, File, UploadFile, Form, HTTPException
from pydantic import BaseModel
from app.services.gemini_service import GeminiService
from app.services.gemini_pool import RateLimitExceeded
from app.services.usda_service import UsdaService
from app.services.barcode_service import BarcodeService
from app.db.supabase_client import get_supabase_admin_client
from app.services.food_db_service import FoodDBService

router = APIRouter()

@router.post("/scan")
async def scan_meal(
    image: UploadFile = File(...),
    user_id: str = Form(...)
):
    try:
        # 1. Fetch user's health profile to get conditions and allergies context
        supabase = get_supabase_admin_client()
        profile_response = supabase.table('health_profiles').select('*').eq('user_id', user_id).maybe_single().execute()
        profile = profile_response.data
        
        # 2. Read image details
        image_bytes = await image.read()
        mime_type = image.content_type or "image/jpeg"
        
        # 3. Analyze plate using Gemini interactions service
        scan_result = GeminiService.scan_meal(
            image_bytes=image_bytes,
            mime_type=mime_type,
            profile=profile
        )
        
        if not scan_result.get("is_food", True):
            raise HTTPException(status_code=400, detail="NO_FOOD_DETECTED")
            
        # 4. Fetch USDA macros for each item and recalculate totals
        total_calories = 0.0
        total_protein = 0.0
        total_carbs = 0.0
        total_fat = 0.0
        
        for item in scan_result.get("items", []):
            usda_macros = await UsdaService.fetch_macros_per_100g(item.get("name", ""))
            
            # Pass the baseline to frontend so it can recalculate live when grams change
            item["macros_per_100g"] = usda_macros 
            
            grams = float(item.get("estimated_weight_g", 0))
            ratio = grams / 100.0
            
            item["calories"] = round(usda_macros["calories"] * ratio)
            item["protein_g"] = round(usda_macros["protein_g"] * ratio, 1)
            item["carbs_g"] = round(usda_macros["carbs_g"] * ratio, 1)
            item["fat_g"] = round(usda_macros["fat_g"] * ratio, 1)
            
            total_calories += item["calories"]
            total_protein += item["protein_g"]
            total_carbs += item["carbs_g"]
            total_fat += item["fat_g"]
            
        scan_result["total_calories"] = round(total_calories)
        scan_result["total_protein_g"] = round(total_protein, 1)
        scan_result["total_carbs_g"] = round(total_carbs, 1)
        scan_result["total_fat_g"] = round(total_fat, 1)
        
        return scan_result
    except RateLimitExceeded:
        raise HTTPException(status_code=429, detail="RATE_LIMITED")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class BarcodeRequest(BaseModel):
    barcode: str
    user_id: str

class SearchFoodRequest(BaseModel):
    query: str

@router.post("/scan-barcode")
async def scan_barcode(req: BarcodeRequest):
    import logging
    logger = logging.getLogger(__name__)
    try:
        # 1. Fetch user's health profile
        supabase = get_supabase_admin_client()
        profile_response = supabase.table('health_profiles').select('*').eq('user_id', req.user_id).maybe_single().execute()
        profile = profile_response.data if profile_response else None

        # ── PATH A: Product exists in local DB ────────────────────────────────
        db_row = FoodDBService.lookup(req.barcode)

        if db_row is not None:
            logger.info(f"Barcode '{req.barcode}' found in local DB: {db_row.get('product_name')}")
            
            # Check if DB row has complete valid macros (Tea/Water with 0.0 are accepted, NULL is not)
            if FoodDBService.is_macro_complete(db_row):
                logger.info(f"DB row has complete macros for '{req.barcode}'.")
                product_data = FoodDBService.format_result(db_row, profile=profile)
                
                # Single call for clinical health evaluation
                ai_warnings = GeminiService.evaluate_ingredients(
                    ingredients=product_data.get("ingredients", ""),
                    allergens=product_data.get("allergens", ""),
                    profile=profile,
                    macros={
                        "calories":  product_data.get("calories"),
                        "carbs_g":   product_data.get("carbs_g"),
                        "fat_g":     product_data.get("fat_g"),
                        "protein_g": product_data.get("protein_g"),
                    },
                )
                keyword_warnings = product_data.get("allergy_warnings", [])
                merged_warnings = ai_warnings if ai_warnings else keyword_warnings
                product_data["allergy_warnings"] = merged_warnings

                return {
                    "product": product_data,
                    "allergy_warnings": merged_warnings,
                    "source": "database"
                }

            else:
                # Macros are missing/NULL or anomalous in DB -> Single combined Gemini call (Fix 7)
                logger.info(f"Incomplete macros for '{req.barcode}' — filling via combined Gemini call for: {db_row.get('product_name')}")
                pname = db_row.get('product_name') or 'Packaged Food'
                brand = db_row.get('brands') or ''
                display_name = f"{brand} · {pname}" if (brand and brand.lower() not in pname.lower()) else pname

                enriched = GeminiService.fill_macros_and_evaluate(
                    product_name=display_name,
                    ingredients=db_row.get('ingredients_text', ''),
                    allergens=db_row.get('allergens_en', ''),
                    profile=profile
                )

                if enriched and enriched.get("calories", 0) > 0:
                    product_data = {
                        'product_name':    display_name,
                        'calories':        enriched["calories"],
                        'protein_g':       enriched["protein_g"],
                        'carbs_g':         enriched["carbs_g"],
                        'fat_g':           enriched["fat_g"],
                        'ingredients':     enriched.get("ingredients") or db_row.get('ingredients_text') or 'Standard ingredients',
                        'allergens':       enriched.get("allergens") or db_row.get('allergens_en') or 'No major allergens',
                        'allergy_warnings': enriched.get("allergy_warnings", []),
                        'source':          'database_enriched',
                    }
                    try:
                        FoodDBService.cache_food(req.barcode, product_data)
                    except Exception:
                        pass
                else:
                    # Fallback to whatever raw DB has if Gemini is rate limited
                    product_data = FoodDBService.format_result(db_row, profile=profile)

                return {
                    "product": product_data,
                    "allergy_warnings": product_data.get("allergy_warnings", []),
                    "source": product_data.get("source", "database")
                }

        # ── PATH B: Not in DB — Fallback 1: OpenFoodFacts -> Fallback 2: Gemini AI ───
        else:
            logger.info(f"Barcode '{req.barcode}' not in local DB — trying OpenFoodFacts API...")
            off_data = None
            try:
                off_data = await BarcodeService.fetch_product_data(req.barcode)
            except Exception as off_err:
                logger.warning(f"OpenFoodFacts lookup failed for '{req.barcode}': {off_err}")

            if off_data and off_data.get("product_name") and off_data.get("product_name") != "Scanned Packaged Food":
                logger.info(f"Barcode '{req.barcode}' resolved via OpenFoodFacts: {off_data.get('product_name')}")
                
                # Check macro completeness of OpenFoodFacts result
                cal = off_data.get("calories")
                fat = off_data.get("fat_g")
                carbs = off_data.get("carbs_g")
                protein = off_data.get("protein_g")
                
                is_off_complete = False
                if fat is not None and carbs is not None and protein is not None:
                    try:
                        f, c, p = float(fat), float(carbs), float(protein)
                        cal_val = float(cal) if cal is not None else 0.0
                        if cal_val > 50 and f == 0.0 and c == 0.0 and p == 0.0:
                            is_off_complete = False  # Anomaly in OpenFoodFacts data
                        elif cal_val <= 25 and f == 0.0 and c == 0.0 and p == 0.0:
                            is_off_complete = True   # Legitimate zero-calorie item (Tea, Water, etc.)
                        elif f > 0 or c > 0 or p > 0:
                            is_off_complete = True   # Valid positive macros
                    except (ValueError, TypeError):
                        is_off_complete = False

                if not is_off_complete:
                    # Macros are NULL or anomalous in OpenFoodFacts -> Call Gemini to fill macros & evaluate health in 1 call
                    logger.info(f"OpenFoodFacts entry for '{req.barcode}' has missing/null macros — enriching via Gemini AI...")
                    enriched = GeminiService.fill_macros_and_evaluate(
                        product_name=off_data.get("product_name", "Packaged Food"),
                        ingredients=off_data.get("ingredients", ""),
                        allergens=off_data.get("allergens", ""),
                        profile=profile
                    )
                    if enriched and enriched.get("calories", 0) > 0:
                        off_data["calories"] = enriched["calories"]
                        off_data["protein_g"] = enriched["protein_g"]
                        off_data["carbs_g"] = enriched["carbs_g"]
                        off_data["fat_g"] = enriched["fat_g"]
                        if enriched.get("ingredients"):
                            off_data["ingredients"] = enriched["ingredients"]
                        if enriched.get("allergens"):
                            off_data["allergens"] = enriched["allergens"]
                        off_data["allergy_warnings"] = enriched.get("allergy_warnings", [])
                        off_data["source"] = "openfoodfacts_enriched"
                    else:
                        off_data["calories"] = off_data.get("calories") or 0
                        off_data["protein_g"] = off_data.get("protein_g") or 0.0
                        off_data["carbs_g"] = off_data.get("carbs_g") or 0.0
                        off_data["fat_g"] = off_data.get("fat_g") or 0.0
                        off_data["allergy_warnings"] = []
                        off_data["source"] = "openfoodfacts"
                else:
                    # OpenFoodFacts macros are complete -> Single call for clinical health & allergy evaluation
                    ai_warnings = GeminiService.evaluate_ingredients(
                        ingredients=off_data.get("ingredients", ""),
                        allergens=off_data.get("allergens", ""),
                        profile=profile,
                        macros={
                            "calories":  off_data.get("calories", 0),
                            "carbs_g":   off_data.get("carbs_g", 0.0),
                            "fat_g":     off_data.get("fat_g", 0.0),
                            "protein_g": off_data.get("protein_g", 0.0),
                        },
                    )
                    off_data["allergy_warnings"] = ai_warnings
                    off_data["source"] = "openfoodfacts"

                # Cache into local DB so future lookups are instant
                try:
                    FoodDBService.cache_food(req.barcode, off_data)
                except Exception:
                    pass

                return {
                    "product": off_data,
                    "allergy_warnings": off_data.get("allergy_warnings", []),
                    "source": off_data.get("source", "openfoodfacts")
                }

            # ── Fallback 2: Not in OpenFoodFacts -> Gemini AI Identification ──
            logger.info(f"Barcode '{req.barcode}' not in OpenFoodFacts — falling back to Gemini AI...")
            try:
                product_data = GeminiService.identify_barcode_food(req.barcode, profile=profile)
                try:
                    FoodDBService.cache_food(req.barcode, product_data)
                except Exception:
                    pass
            except Exception as gemini_err:
                logger.error(f"Gemini failed for barcode '{req.barcode}': {gemini_err}")
                raise HTTPException(
                    status_code=503,
                    detail="Could not identify this product. Please try again or enter the food details manually."
                )

            return {
                "product": product_data,
                "allergy_warnings": product_data.get("allergy_warnings", []),
                "source": "ai",
            }

    except HTTPException:
        raise
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(f"Barcode scan failed for '{req.barcode}': {type(e).__name__}: {e}")
        raise HTTPException(status_code=500, detail="Unable to identify food item at this moment.")


@router.get("/weekly-report")
def get_weekly_report(user_id: str, language: str = "en"):
    try:
        from app.services.report_service import ReportService
        return ReportService.generate_weekly_report(user_id=user_id, language=language)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/search-food")
async def search_food(req: SearchFoodRequest):
    try:
        macros = GeminiService.estimate_food_macros(req.query)
        return macros
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/grocery-list/{user_id}")
async def get_grocery_list(user_id: str):
    try:
        supabase = get_supabase_admin_client()
        
        # 1. Fetch profile
        profile_res = supabase.table('health_profiles').select('*').eq('user_id', user_id).maybe_single().execute()
        profile = profile_res.data
        
        # 2. Fetch past 7 days of meals (using UTC bounds)
        import datetime
        now_utc = datetime.datetime.now(datetime.timezone.utc)
        start_date = now_utc.date() - datetime.timedelta(days=7)
        
        meals_res = supabase.table('meal_logs') \
            .select('notes') \
            .eq('user_id', user_id) \
            .gte('logged_at', f"{start_date.isoformat()}T00:00:00+00:00") \
            .execute()
        meals = meals_res.data or []
        recent_meal_notes = [m.get('notes') for m in meals if m.get('notes')]
        
        # 3. Generate grocery list
        grocery_list = GeminiService.generate_grocery_list(recent_meal_notes, profile)
        return grocery_list
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
