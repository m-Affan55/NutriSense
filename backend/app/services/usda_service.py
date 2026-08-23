import httpx
import logging

logger = logging.getLogger(__name__)

class UsdaService:
    API_URL = "https://api.nal.usda.gov/fdc/v1/foods/search"
    # Using the public demo key for hackathon purposes.
    # Note: Limited to 30 requests per IP per minute.
    API_KEY = "DEMO_KEY"

    @staticmethod
    async def fetch_macros_per_100g(food_name: str) -> dict:
        """
        Queries the USDA FoodData Central API to find the closest match for the food item.
        Returns macros per 100g.
        """
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    UsdaService.API_URL,
                    params={
                        "api_key": UsdaService.API_KEY,
                        "query": food_name,
                        "pageSize": 1,
                        "dataType": "Foundation,SR Legacy,Survey (FNDDS)"
                    },
                    timeout=5.0
                )
                
                if response.status_code == 200:
                    data = response.json()
                    foods = data.get("foods", [])
                    if foods:
                        food = foods[0]
                        nutrients = food.get("foodNutrients", [])
                        
                        # USDA Nutrient IDs: 1008 = Calories, 1003 = Protein, 1005 = Carbs, 1004 = Fat
                        macros = {
                            "calories": 0.0,
                            "protein_g": 0.0,
                            "carbs_g": 0.0,
                            "fat_g": 0.0
                        }
                        
                        for nutrient in nutrients:
                            nid = nutrient.get("nutrientId")
                            val = float(nutrient.get("value", 0))
                            if nid == 1008:
                                macros["calories"] = val
                            elif nid == 1003:
                                macros["protein_g"] = val
                            elif nid == 1005:
                                macros["carbs_g"] = val
                            elif nid == 1004:
                                macros["fat_g"] = val
                                
                        return macros
                        
        except Exception as e:
            logger.error(f"USDA lookup failed for {food_name}: {e}")
            
        # Fallback if USDA fails or food not found: return zeros (user will have to edit manually or we rely on Gemini's guess)
        # For this architecture, returning 0s is safer than hallucinating, but we could also ask Gemini as a fallback.
        # We will return 0s to force the user to provide valid data if the lookup completely fails.
        return {
            "calories": 0.0,
            "protein_g": 0.0,
            "carbs_g": 0.0,
            "fat_g": 0.0
        }
