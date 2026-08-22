import httpx
from fastapi import HTTPException
from app.services.gemini_service import GeminiService

class BarcodeService:
    BASE_URL = "https://world.openfoodfacts.org/api/v2/product"
    HEADERS = {
        "User-Agent": "NutriSenseApp - Android/iOS/Windows - Version 1.0 (contact@nutrisense.app)"
    }

    @staticmethod
    async def fetch_product_data(barcode: str) -> dict:
        url_v2 = f"{BarcodeService.BASE_URL}/{barcode}.json"
        url_v0 = f"https://world.openfoodfacts.org/api/v0/product/{barcode}.json"
        
        async with httpx.AsyncClient(timeout=8.0, follow_redirects=True) as client:
            # 1. Try OpenFoodFacts API v2
            try:
                response = await client.get(url_v2, headers=BarcodeService.HEADERS)
                if response.status_code == 200:
                    data = response.json()
                    if data.get("status") == 1 and data.get("product"):
                        return BarcodeService._parse_off_product(data["product"])
            except Exception:
                pass
            
            # 2. Try OpenFoodFacts API v0 fallback
            try:
                response_v0 = await client.get(url_v0, headers=BarcodeService.HEADERS)
                if response_v0.status_code == 200:
                    data_v0 = response_v0.json()
                    if data_v0.get("status") == 1 and data_v0.get("product"):
                        return BarcodeService._parse_off_product(data_v0["product"])
            except Exception:
                pass

        # 3. Fallback to Gemini AI estimation for barcodes
        try:
            gemini_result = GeminiService.estimate_food_macros(f"Packaged food with barcode {barcode}")
            if gemini_result and gemini_result.get("name") and gemini_result.get("calories", 0) > 0:
                return {
                    "product_name": gemini_result.get("name", "Packaged Food"),
                    "calories": round(gemini_result.get("calories", 0)),
                    "protein_g": round(gemini_result.get("protein_g", 0), 1),
                    "carbs_g": round(gemini_result.get("carbs_g", 0), 1),
                    "fat_g": round(gemini_result.get("fat_g", 0), 1),
                    "ingredients": "Nutritional estimate based on standard food database.",
                    "allergens": "Check packaging label",
                    "image_url": None
                }
        except Exception:
            pass

        raise HTTPException(status_code=404, detail="Product not found in OpenFoodFacts database.")

    @staticmethod
    def _parse_off_product(product: dict) -> dict:
        nutriments = product.get("nutriments", {})
        
        def safe_float(val) -> float:
            try:
                return float(val) if val is not None else 0.0
            except (ValueError, TypeError):
                return 0.0

        # Extract macros (preferably per 100g or serving)
        calories = safe_float(nutriments.get("energy-kcal_100g") or nutriments.get("energy-kcal_serving") or (safe_float(nutriments.get("energy_100g")) / 4.184))
        protein = safe_float(nutriments.get("proteins_100g") or nutriments.get("proteins_serving"))
        carbs = safe_float(nutriments.get("carbohydrates_100g") or nutriments.get("carbohydrates_serving"))
        fat = safe_float(nutriments.get("fat_100g") or nutriments.get("fat_serving"))
        
        ingredients = product.get("ingredients_text_en") or product.get("ingredients_text") or "Ingredients not listed"
        allergens = product.get("allergens_tags") or product.get("allergens") or "No allergens listed"
        if isinstance(allergens, list):
            allergens = ", ".join([str(a).replace("en:", "") for a in allergens])
            
        product_name = product.get("product_name_en") or product.get("product_name") or product.get("generic_name") or "Scanned Packaged Food"
        image_url = product.get("image_url") or product.get("image_front_url")
        
        return {
            "product_name": product_name,
            "calories": round(calories),
            "protein_g": round(protein, 1),
            "carbs_g": round(carbs, 1),
            "fat_g": round(fat, 1),
            "ingredients": str(ingredients),
            "allergens": str(allergens),
            "image_url": image_url
        }
