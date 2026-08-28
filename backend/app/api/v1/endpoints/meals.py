import asyncio
from fastapi import APIRouter, File, UploadFile, Form, HTTPException, Depends
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel, Field
from app.services.gemini_service import GeminiService
from app.services.gemini_pool import RateLimitExceeded
from app.services.usda_service import UsdaService
from app.services.barcode_service import BarcodeService
from app.db.supabase_client import get_supabase_admin_client
from app.services.food_db_service import FoodDBService
from app.core.security import get_current_user_id

router = APIRouter()

@router.post("/scan")
async def scan_meal(
    image: UploadFile = File(...),
    user_id: str = Form(...),
    authenticated_user_id: str = Depends(get_current_user_id)
):
    if user_id != authenticated_user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You do not own this resource")

    try:
        # 1. Fetch user's health profile (non-blocking thread pool)
        supabase = get_supabase_admin_client()
        profile_response = await run_in_threadpool(
            lambda: supabase.table('health_profiles').select('*').eq('user_id', user_id).maybe_single().execute()
        )
        profile = profile_response.data
        
        # 2. Read image details
        image_bytes = await image.read()
        mime_type = image.content_type or "image/jpeg"
        
        # 3. Analyze plate using Gemini service (non-blocking thread pool)
        scan_result = await run_in_threadpool(
            GeminiService.scan_meal,
            image_bytes,
            mime_type,
            profile
        )
        
        if not scan_result.get("is_food", True):
            raise HTTPException(status_code=400, detail="NO_FOOD_DETECTED")
            
        # 4. Fetch USDA macros in parallel using asyncio.gather
        total_calories = 0.0
        total_protein = 0.0
        total_carbs = 0.0
        total_fat = 0.0
        
        items = scan_result.get("items", [])
        usda_tasks = [UsdaService.fetch_macros_per_100g(item.get("name", "")) for item in items]
        usda_results = await asyncio.gather(*usda_tasks)
        
        for item, usda_macros in zip(items, usda_results):
            grams = float(item.get("estimated_weight_g", 0))
            ratio = (grams / 100.0) if grams > 0 else 1.0
            
            has_usda = usda_macros.get("calories", 0) > 0 or usda_macros.get("protein_g", 0) > 0 or usda_macros.get("carbs_g", 0) > 0 or usda_macros.get("fat_g", 0) > 0
            
            if has_usda:
                item["macros_per_100g"] = usda_macros
                item["calories"] = round(usda_macros["calories"] * ratio)
                item["protein_g"] = round(usda_macros["protein_g"] * ratio, 1)
                item["carbs_g"] = round(usda_macros["carbs_g"] * ratio, 1)
                item["fat_g"] = round(usda_macros["fat_g"] * ratio, 1)
                item["macro_source"] = "usda"
            else:
                # USDA lookup did not have data (e.g. South Asian / regional dish)
                # Keep Gemini's rich AI item estimates and derive per-100g baseline for frontend portion sliders
                item_cal = float(item.get("calories", 0))
                item_pro = float(item.get("protein_g", 0))
                item_carb = float(item.get("carbs_g", 0))
                item_fat = float(item.get("fat_g", 0))
                
                if grams > 0:
                    item["macros_per_100g"] = {
                        "calories": round((item_cal / grams) * 100.0, 1),
                        "protein_g": round((item_pro / grams) * 100.0, 1),
                        "carbs_g": round((item_carb / grams) * 100.0, 1),
                        "fat_g": round((item_fat / grams) * 100.0, 1),
                    }
                else:
                    item["macros_per_100g"] = {
                        "calories": item_cal,
                        "protein_g": item_pro,
                        "carbs_g": item_carb,
                        "fat_g": item_fat,
                    }
                item["macro_source"] = "ai_estimate"
            
            total_calories += item.get("calories", 0)
            total_protein += item.get("protein_g", 0)
            total_carbs += item.get("carbs_g", 0)
            total_fat += item.get("fat_g", 0)
            
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
    barcode: str = Field(..., pattern=r'^\d{4,18}$', description="Barcode must contain 4 to 18 digits only")
    user_id: str = Field(..., min_length=1, max_length=128)

class SearchFoodRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=300, description="Search query limited to 300 characters")

@router.post("/scan-barcode")
async def scan_barcode(req: BarcodeRequest, authenticated_user_id: str = Depends(get_current_user_id)):
    if req.user_id != authenticated_user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You do not own this resource")

    import logging
    logger = logging.getLogger(__name__)
    try:
        # 1. Fetch user's health profile (non-blocking thread pool)
        supabase = get_supabase_admin_client()
        profile_response = await run_in_threadpool(
            lambda: supabase.table('health_profiles').select('*').eq('user_id', req.user_id).maybe_single().execute()
        )
        profile = profile_response.data if profile_response else None

        # ── PATH A: Product exists in local DB ────────────────────────────────
        db_row = await run_in_threadpool(FoodDBService.lookup, req.barcode)

        if db_row is not None:
            logger.info(f"Barcode '{req.barcode}' found in local DB: {db_row.get('product_name')}")
            
            # Check if DB row has complete valid macros
            if FoodDBService.is_macro_complete(db_row):
                logger.info(f"DB row has complete macros for '{req.barcode}'.")
                product_data = FoodDBService.format_result(db_row, profile=profile)
                
                # Single call for clinical health evaluation (non-blocking thread pool)
                ai_warnings = await run_in_threadpool(
                    GeminiService.evaluate_ingredients,
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
                # Macros are missing/NULL or anomalous in DB -> Single combined Gemini call (non-blocking thread pool)
                logger.info(f"Incomplete macros for '{req.barcode}' — filling via combined Gemini call for: {db_row.get('product_name')}")
                pname = db_row.get('product_name') or 'Packaged Food'
                brand = db_row.get('brands') or ''
                display_name = f"{brand} · {pname}" if (brand and brand.lower() not in pname.lower()) else pname

                enriched = await run_in_threadpool(
                    GeminiService.fill_macros_and_evaluate,
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
                        await run_in_threadpool(FoodDBService.cache_food, req.barcode, product_data)
                    except Exception:
                        pass
                else:
                    # Fallback to whatever raw DB has if Gemini fails
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
                            is_off_complete = False
                        elif cal_val <= 25 and f == 0.0 and c == 0.0 and p == 0.0:
                            is_off_complete = True
                        elif f > 0 or c > 0 or p > 0:
                            is_off_complete = True
                    except (ValueError, TypeError):
                        is_off_complete = False

                if not is_off_complete:
                    # Macros are NULL or anomalous in OpenFoodFacts -> Call Gemini to fill macros & evaluate health in 1 call (non-blocking thread pool)
                    logger.info(f"OpenFoodFacts entry for '{req.barcode}' has missing/null macros — enriching via Gemini AI...")
                    enriched = await run_in_threadpool(
                        GeminiService.fill_macros_and_evaluate,
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
                    # OpenFoodFacts macros are complete -> Single call for clinical health & allergy evaluation (non-blocking thread pool)
                    ai_warnings = await run_in_threadpool(
                        GeminiService.evaluate_ingredients,
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

                # Cache into local DB (non-blocking thread pool)
                try:
                    await run_in_threadpool(FoodDBService.cache_food, req.barcode, off_data)
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
                product_data = await run_in_threadpool(GeminiService.identify_barcode_food, req.barcode, profile)
                try:
                    await run_in_threadpool(FoodDBService.cache_food, req.barcode, product_data)
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
async def get_weekly_report(user_id: str, language: str = "en", authenticated_user_id: str = Depends(get_current_user_id)):
    if user_id != authenticated_user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You do not own this resource")
        
    try:
        from app.services.report_service import ReportService
        return await run_in_threadpool(ReportService.generate_weekly_report, user_id=user_id, language=language)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/search-food")
async def search_food(req: SearchFoodRequest, authenticated_user_id: str = Depends(get_current_user_id)):
    try:
        macros = await run_in_threadpool(GeminiService.estimate_food_macros, req.query)
        return macros
    except RateLimitExceeded:
        raise HTTPException(status_code=429, detail="RATE_LIMITED")
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e))

@router.get("/grocery-list/{user_id}")
async def get_grocery_list(user_id: str, authenticated_user_id: str = Depends(get_current_user_id)):
    if user_id != authenticated_user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You do not own this resource")
        
    try:
        supabase = get_supabase_admin_client()
        
        # 1. Fetch profile (non-blocking thread pool)
        profile_res = await run_in_threadpool(
            lambda: supabase.table('health_profiles').select('*').eq('user_id', user_id).maybe_single().execute()
        )
        profile = profile_res.data
        
        # 2. Fetch past 7 days of meals (using UTC bounds)
        import datetime
        now_utc = datetime.datetime.now(datetime.timezone.utc)
        start_date = now_utc.date() - datetime.timedelta(days=7)
        
        meals_res = await run_in_threadpool(
            lambda: supabase.table('meal_logs')
                .select('notes')
                .eq('user_id', user_id)
                .gte('logged_at', f"{start_date.isoformat()}T00:00:00+00:00")
                .execute()
        )
        meals = meals_res.data or []
        recent_meal_notes = [m.get('notes') for m in meals if m.get('notes')]
        
        # 3. Generate grocery list (non-blocking thread pool)
        grocery_list = await run_in_threadpool(GeminiService.generate_grocery_list, recent_meal_notes, profile)
        return grocery_list
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
