import httpx
from fastapi import HTTPException

class BarcodeService:
    BASE_URL = "https://world.openfoodfacts.org/api/v2/product"

    @staticmethod
    async def fetch_product_data(barcode: str) -> dict:
        url = f"{BarcodeService.BASE_URL}/{barcode}.json"
        
        async with httpx.AsyncClient() as client:
            response = await client.get(url)
            
            if response.status_code != 200:
                raise HTTPException(status_code=404, detail="Product not found in OpenFoodFacts database.")
            
            data = response.json()
            if data.get("status") != 1:
                raise HTTPException(status_code=404, detail="Product not found in OpenFoodFacts database.")
                
            product = data.get("product", {})
            
            nutriments = product.get("nutriments", {})
            
            # Extract macros (preferably per 100g or serving)
            calories = nutriments.get("energy-kcal_100g") or nutriments.get("energy-kcal_serving") or 0
            protein = nutriments.get("proteins_100g") or nutriments.get("proteins_serving") or 0
            carbs = nutriments.get("carbohydrates_100g") or nutriments.get("carbohydrates_serving") or 0
            fat = nutriments.get("fat_100g") or nutriments.get("fat_serving") or 0
            
            ingredients = product.get("ingredients_text_en") or product.get("ingredients_text") or "Ingredients not available"
            allergens = product.get("allergens") or "No allergens listed"
            product_name = product.get("product_name_en") or product.get("product_name") or "Unknown Product"
            image_url = product.get("image_url") or product.get("image_front_url")
            
            return {
                "product_name": product_name,
                "calories": round(float(calories)),
                "protein_g": round(float(protein), 1),
                "carbs_g": round(float(carbs), 1),
                "fat_g": round(float(fat), 1),
                "ingredients": ingredients,
                "allergens": allergens,
                "image_url": image_url
            }
