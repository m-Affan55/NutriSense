import httpx
from typing import Optional

class BarcodeService:
    BASE_URL = "https://world.openfoodfacts.org/api/v2/product"
    HEADERS = {
        "User-Agent": "NutriSenseApp - Android/iOS/Windows - Version 1.0 (contact@nutrisense.app)"
    }

    @staticmethod
    async def fetch_product_data(barcode: str) -> Optional[dict]:
        clean_code = str(barcode).strip()
        url_v2 = f"{BarcodeService.BASE_URL}/{clean_code}.json"
        url_v0 = f"https://world.openfoodfacts.org/api/v0/product/{clean_code}.json"
        
        # 5.0s read timeout, 3.0s connect timeout for slow/unstable networks
        timeout_config = httpx.Timeout(5.0, connect=3.0)
        async with httpx.AsyncClient(timeout=timeout_config, follow_redirects=True) as client:
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

        return None

    @staticmethod
    def _parse_off_product(product: dict) -> dict:
        nutriments = product.get("nutriments", {})
        
        def safe_float(val) -> Optional[float]:
            if val is None:
                return None
            val_str = str(val).strip()
            if not val_str or val_str.lower() in ('none', 'nan', 'null', ''):
                return None
            try:
                return float(val_str)
            except (ValueError, TypeError):
                return None

        # Extract macros (preserve None if missing from OpenFoodFacts)
        cal_raw = safe_float(nutriments.get("energy-kcal_100g") or nutriments.get("energy-kcal_serving") or nutriments.get("energy-kcal"))
        if cal_raw is None and nutriments.get("energy_100g") is not None:
            e_kj = safe_float(nutriments.get("energy_100g"))
            if e_kj is not None:
                cal_raw = e_kj / 4.184

        prot_raw = safe_float(nutriments.get("proteins_100g") or nutriments.get("proteins_serving") or nutriments.get("proteins"))
        carbs_raw = safe_float(nutriments.get("carbohydrates_100g") or nutriments.get("carbohydrates_serving") or nutriments.get("carbohydrates"))
        fat_raw = safe_float(nutriments.get("fat_100g") or nutriments.get("fat_serving") or nutriments.get("fat"))

        ingredients = product.get("ingredients_text_en") or product.get("ingredients_text") or "Ingredients not listed"
        allergens = product.get("allergens_tags") or product.get("allergens") or "No allergens listed"
        if isinstance(allergens, list):
            allergens = ", ".join([str(a).replace("en:", "").replace("fr:", "") for a in allergens])
            
        raw_name = product.get("product_name_en") or product.get("product_name") or product.get("generic_name") or "Scanned Packaged Food"
        brand = product.get("brands") or ""
        display_name = f"{brand} · {raw_name}" if (brand and brand.lower() not in raw_name.lower()) else raw_name
        image_url = product.get("image_url") or product.get("image_front_url")
        
        return {
            "product_name": display_name,
            "calories": round(cal_raw) if cal_raw is not None else None,
            "protein_g": round(prot_raw, 1) if prot_raw is not None else None,
            "carbs_g": round(carbs_raw, 1) if carbs_raw is not None else None,
            "fat_g": round(fat_raw, 1) if fat_raw is not None else None,
            "ingredients": str(ingredients),
            "allergens": str(allergens),
            "image_url": image_url,
            "source": "openfoodfacts"
        }
