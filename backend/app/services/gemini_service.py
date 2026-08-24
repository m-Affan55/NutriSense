import base64
import json
import re
from google.genai import types
from app.core.config import settings
from app.schemas.meal import MealScanResponse
from app.services.gemini_pool import gemini_pool

class GeminiService:
    @staticmethod
    def _parse_gemini_json(raw_text: str) -> dict:
        cleaned = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw_text.strip())
        try:
            return json.loads(cleaned)
        except json.JSONDecodeError:
            raise RuntimeError("Model returned malformed JSON")

    @staticmethod
    def scan_meal(image_bytes: bytes, mime_type: str, profile: dict = None) -> dict:
        system_instruction = """
        You are a precise food and meal image recognition system.
        Look directly at the visual elements in the photograph and identify the authentic name of the dish shown.
        Base your recognition strictly on the actual food visible in the image.
        If the image does not contain food, or you cannot identify any food item with reasonable confidence, set is_food to false and leave nutrition fields empty/0.
        Otherwise, set is_food to true and provide an initial estimate of portion sizes in grams.
        Set recognition_confidence to 'high' if the image is clear and identifiable, or 'low' if blurry or unclear.
        """

        prompt = "Analyze the food shown in this image and return the complete nutritional breakdown according to the schema."
        
        response = gemini_pool.generate_content(
            model='gemini-3.7-flash',
            contents=[
                types.Part.from_bytes(
                    data=image_bytes,
                    mime_type=mime_type
                ),
                prompt
            ],
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.0,
                response_mime_type="application/json",
                response_schema=MealScanResponse,
            ),
        )
        
        try:
            return GeminiService._parse_gemini_json(response.text)
        except Exception as e:
            raise RuntimeError(f"Failed to parse meal scan results. Please try again. Detailed error: {str(e)}")

    @staticmethod
    def evaluate_ingredients(
        ingredients: str,
        allergens: str,
        profile: dict = None,
        macros: dict = None,
    ) -> list[str]:
        """
        Uses Gemini AI to evaluate a product's ingredients, allergens, and macros
        against the user's health profile and medical conditions.
        Supports both ingredient-based AND macro-based clinical triggers
        (e.g., high carbs for Diabetes, high fat for Diarrhoea/Pancreatitis).
        """
        if not profile:
            return []

        conditions_str = ', '.join(profile.get('medical_conditions', [])) if profile.get('medical_conditions') else 'None'
        restrictions_str = ', '.join(profile.get('dietary_restrictions', [])) if profile.get('dietary_restrictions') else 'None'
        allergies_str = ', '.join(profile.get('allergies', [])) if profile.get('allergies') else 'None'

        macro_context = ""
        if macros:
            macro_context = f"""
        Nutritional Values Per Serving:
        - Calories: {macros.get('calories', 'Unknown')} kcal
        - Carbohydrates: {macros.get('carbs_g', 'Unknown')} g
        - Fat: {macros.get('fat_g', 'Unknown')} g
        - Protein: {macros.get('protein_g', 'Unknown')} g
        """

        carbs_val = macros.get('carbs_g', '?') if macros else '?'
        fat_val = macros.get('fat_g', '?') if macros else '?'

        prompt = f"""You are an expert clinical nutritionist and medical safety evaluator.

The user has scanned a packaged food product with the following details:
Ingredients: {ingredients or 'Not specified'}
Listed Allergens: {allergens or 'Not specified'}
{macro_context}
The user's health profile:
- Medical Conditions: {conditions_str}
- Known Allergies: {allergies_str}
- Dietary Restrictions: {restrictions_str}

Task:
Analyze ALL of the above — ingredients, allergens, AND nutritional values — against the user's health profile.
Use your full medical and nutritional knowledge to identify ANY conflicts. The examples below are illustrative, NOT exhaustive — apply clinical reasoning for ALL conditions the user has listed, even if they are not mentioned below.

Clinical rules to apply (examples only):
- Diabetes / High Blood Sugar: Warn if carbs > 45g per serving, or if ingredients contain added sugars (sugar, glucose, fructose, corn syrup, dextrose, honey, maltose, caramel).
- Diarrhoea / IBS / Digestive Issues: Warn if fat > 15g per serving, or if product contains artificial sweeteners (sorbitol, mannitol, xylitol), high-fibre grains, spicy ingredients, lactose, or excessive caffeine.
- Hypertension / High Blood Pressure: Warn if product contains salt, sodium, MSG, or soy sauce in significant quantities.
- Celiac Disease / Gluten Intolerance: Warn if ingredients contain wheat, gluten, barley, rye, or malt.
- Lactose Intolerance: Warn if ingredients contain milk, lactose, cream, cheese, whey, or butter.
- Kidney Disease / Renal Failure: Warn if product is high in potassium, phosphorus, or sodium.
- Heart Disease: Warn if product contains trans fats, saturated fats > 10g, or high sodium.
- Peanut / Nut Allergy: Warn if allergens or ingredients mention peanuts, groundnuts, tree nuts, almonds, cashews, walnuts, hazelnuts.
- Gout: Warn if product is high in purines (organ meats, shellfish, red meat extracts, yeast extract, beer).
- PCOS / Insulin Resistance: Warn if product is high in refined carbs, added sugars, or trans fats.
- Thyroid / Hypothyroidism: Warn if product contains raw cruciferous vegetables (broccoli, kale, soy) that can affect iodine uptake.
- Any other condition the user has listed: Use your medical knowledge to determine if this product is safe or harmful.

If there are NO conflicts, return an empty list [].

Return ONLY a JSON array of warning strings. Be specific and mention actual values. Examples:
["WARNING: High in carbohydrates ({carbs_val}g) — may spike blood sugar levels. Portion control is recommended for managing Diabetes / High Blood Sugar."]
["CRITICAL: This product contains peanuts which conflicts with your Peanut Allergy!"]
["WARNING: High fat content ({fat_val}g) — high-fat foods can worsen Diarrhoea and digestive discomfort."]
[]
"""
        try:
            response = gemini_pool.generate_content(
                model='gemini-3.7-flash',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                ),
                max_retries=1,
            )
            return json.loads(response.text)
        except Exception:
            return []

    @staticmethod
    def estimate_food_macros(query: str) -> dict:
        prompt = f"""
        You are an expert clinical dietitian and nutritional database engine with comprehensive grounding in the USDA Food Data Central and South Asian / Pakistani / Middle Eastern culinary databases (including Ramadan foods like Sehri/Iftar items: Paratha, Roti, Daal, Biryani, Nihari, Haleem, Chana Chaat, Pakoras, Jalebi, Chai, Lassi, Rooh Afza, Khajoor/Dates, Omelette, Fruits).
        
        The user wants to log the following meal/food item: "{query}".
        
        Task:
        1. Parse all items and quantities mentioned (e.g., "2 Aloo Parathas and 1 Chai").
        2. Calculate the combined total nutritional values across all items in the meal description.
        3. If quantity is not specified, assume 1 standard adult serving.
        
        Return ONLY a valid JSON object with the following exact keys:
        - "name": Standardized, appetizing name of the meal (e.g., "Aloo Parathas (2) with Milk Tea")
        - "calories": Integer (total calories in kcal)
        - "protein_g": Float (total protein in grams, rounded to 1 decimal place)
        - "carbs_g": Float (total carbohydrates in grams, rounded to 1 decimal place)
        - "fat_g": Float (total fat in grams, rounded to 1 decimal place)
        """
        
        try:
            response = gemini_pool.generate_content(
                model='gemini-3.7-flash',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                ),
            )
            data = json.loads(response.text)
            return {
                "name": data.get("name", query.title()),
                "calories": int(data.get("calories", 0)),
                "protein_g": float(data.get("protein_g", 0.0)),
                "carbs_g": float(data.get("carbs_g", 0.0)),
                "fat_g": float(data.get("fat_g", 0.0)),
                "is_fallback": False
            }
        except Exception as e:
            # Re-raise so the caller/API knows Gemini estimation failed
            # rather than silently fabricating hardcoded nutrition data.
            raise RuntimeError(f"Gemini macro estimation failed for '{query}': {str(e)}")

    @staticmethod
    def fill_macros_and_evaluate(
        product_name: str,
        ingredients: str = "",
        allergens: str = "",
        profile: dict = None
    ) -> dict:
        """
        Single combined Gemini AI call that:
        1. Estimates accurate standard macros (calories, protein, carbs, fat) for product_name
        2. Evaluates allergies and clinical health warnings against user's profile
        This prevents doing 2 serial Gemini calls (Fix 7).
        """
        conditions_str = ', '.join(profile.get('medical_conditions', [])) if profile and profile.get('medical_conditions') else 'None'
        restrictions_str = ', '.join(profile.get('dietary_restrictions', [])) if profile and profile.get('dietary_restrictions') else 'None'
        allergies_str = ', '.join(profile.get('allergies', [])) if profile and profile.get('allergies') else 'None'

        prompt = f"""You are an expert clinical nutritionist and food database.
The user has scanned a food product with missing nutritional breakdown:
Product: {product_name}
Known Ingredients: {ingredients or 'Standard ingredients for this product'}
Known Allergens: {allergens or 'Not specified'}

User's Health Profile:
- Medical Conditions: {conditions_str}
- Known Allergies: {allergies_str}
- Dietary Restrictions: {restrictions_str}

Tasks:
1. Estimate accurate nutritional values per standard serving/100g (Calories kcal, Protein g, Carbs g, Fat g).
2. Apply clinical dietary rules against the calculated nutritional values and ingredients (e.g. Diabetes: warn if carbs > 45g or added sugar; Diarrhoea: warn if fat > 15g, artificial sweeteners, or lactose; Hypertension: sodium; Celiac: gluten; Allergies: peanuts, dairy, tree nuts).
3. If conflicts exist, list specific clinical warnings in allergy_warnings array. If safe, return empty array [].

Return ONLY a valid JSON object with exact keys:
- "calories": Integer (kcal)
- "protein_g": Float
- "carbs_g": Float
- "fat_g": Float
- "ingredients": String
- "allergens": String
- "allergy_warnings": Array of strings
"""
        try:
            response = gemini_pool.generate_content(
                model='gemini-3.7-flash',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                ),
                max_retries=1,
            )
            result = json.loads(response.text)
            return {
                "calories":         int(result.get("calories", 0)),
                "protein_g":        float(result.get("protein_g", 0.0)),
                "carbs_g":          float(result.get("carbs_g", 0.0)),
                "fat_g":            float(result.get("fat_g", 0.0)),
                "ingredients":      result.get("ingredients", ingredients or "Standard ingredients"),
                "allergens":        result.get("allergens", allergens or "No major allergens"),
                "allergy_warnings": result.get("allergy_warnings", [])
            }
        except Exception:
            return {}

    @staticmethod
    def identify_barcode_food(barcode: str, profile: dict = None) -> dict:

        allergies_str = ', '.join(profile.get('allergies', [])) if profile and profile.get('allergies') else 'None'
        conditions_str = ', '.join(profile.get('medical_conditions', [])) if profile and profile.get('medical_conditions') else 'None'
        
        prompt = f"""
        You are an advanced AI food intelligence system with comprehensive knowledge of global food products, barcodes (EAN-13, UPC, GTIN), packaged groceries, snacks, beverages, and regional brands (including International and South Asian/Pakistani products like Shan, National, Olper's, Mitchell's, Dawn, Tapal, Peak Freans, Lipton, Nestlé, Ferrero, Mars, Mondelez).

        The user scanned or entered the following product barcode: "{barcode}".

        Tasks:
        1. Identify the exact food or beverage product corresponding to this barcode (for example, 3017620422003 is Nutella Hazelnut Spread, 5000159461122 is Snickers Bar, 7622210449283 is Oreo Cookies, 5449000000996 is Coca-Cola, 7613035799982 is KitKat, 9002490100070 is Red Bull, etc.). If the barcode is less common or custom, identify the most likely packaged food item.
        2. Calculate standard nutritional breakdown: Calories (kcal), Protein (g), Carbs (g), Fat (g).
        3. List standard ingredients and allergen notes.
        4. Cross-check against user's health profile:
           - User Allergies: {allergies_str}
           - Medical Conditions: {conditions_str}
           If any ingredient conflicts with their health profile, generate clinical warning bullet points.

        Return ONLY a valid JSON object with the following exact keys:
        - "product_name": String (e.g., "Nutella Hazelnut Spread")
        - "calories": Integer (e.g., 539)
        - "protein_g": Float (e.g., 6.3)
        - "carbs_g": Float (e.g., 57.5)
        - "fat_g": Float (e.g., 30.9)
        - "ingredients": String (e.g., "Sugar, palm oil, hazelnuts (13%), skimmed milk powder, low-fat cocoa, soy lecithin, vanillin")
        - "allergens": String (e.g., "Tree Nuts (Hazelnuts), Milk, Soy")
        - "allergy_warnings": Array of strings (e.g., ["Contains tree nuts (hazelnuts)", "Contains milk/dairy"])
        """
        
        try:
            response = gemini_pool.generate_content(
                model='gemini-3.7-flash',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                ),
            )
            result = json.loads(response.text)
            return {
                "product_name": result.get("product_name", f"Food Item ({barcode})"),
                "calories": int(result.get("calories", 250)),
                "protein_g": float(result.get("protein_g", 5.0)),
                "carbs_g": float(result.get("carbs_g", 30.0)),
                "fat_g": float(result.get("fat_g", 10.0)),
                "ingredients": result.get("ingredients", "Standard food ingredients"),
                "allergens": result.get("allergens", "No major allergens identified"),
                "allergy_warnings": result.get("allergy_warnings", [])
            }
        except Exception as e:
            # Re-raise so the GeminiPool key rotation can handle 429s,
            # and so callers can surface a proper error to the user
            # instead of returning silent dummy/phantom nutrition data.
            raise


    @staticmethod
    def generate_coaching_summary(score: float, profile: dict = None) -> str:
        profile_context = ""
        if profile:
            profile_context = f"""
            The user's health profile:
            - Goal: {profile.get('goal', 'N/A')}
            - Medical Conditions: {', '.join(profile.get('medical_conditions', [])) if profile.get('medical_conditions') else 'None'}
            """
            
        prompt = f"""
        You are an AI nutrition coach. The user has a 30-day habit score of {score:.1f}/100.
        {profile_context}
        
        Write a short, personalized, encouraging one-paragraph coaching message (max 3 sentences) 
        reflecting on their score and giving one piece of actionable advice tailored to their profile.
        """
        try:
            response = gemini_pool.generate_content(
                model='gemini-3.7-flash',
                contents=[prompt],
            )
            return response.text.strip()
        except Exception:
            if score >= 80:
                return "Fantastic job! Your consistency is paying off. Keep up the great work!"
            elif score >= 50:
                return "You're making good progress. A little more consistency with your macro targets will boost your score!"
            else:
                return "Keep logging your meals! Consistency is key to improving your habit score."

    @staticmethod
    def generate_food_swaps(recent_meals: list[str], profile: dict = None) -> list[dict]:
        profile_context = ""
        if profile:
            profile_context = f"""
            The user's health profile:
            - Goal: {profile.get('goal', 'N/A')}
            - Medical Conditions: {', '.join(profile.get('medical_conditions', [])) if profile.get('medical_conditions') else 'None'}
            """
            
        prompt = f"""
        You are an expert nutritionist. The user recently ate these items:
        {json.dumps(recent_meals)}
        
        {profile_context}
        
        Identify up to 3 items from their recent meals that could be swapped for a healthier alternative. 
        The healthier alternative should align with their health goals and medical conditions. 
        It does NOT need to be a Pakistani food; any healthier, realistic alternative is great.
        
        Return ONLY a JSON array of objects with exact keys:
        - "original_food": string (what they ate)
        - "healthy_swap": string (what they should eat instead)
        - "reason": string (short reason why, e.g., "Saves ~110 kcal and 8g fat")
        """
        try:
            response = gemini_pool.generate_content(
                model='gemini-3.7-flash',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                ),
            )
            return json.loads(response.text)
        except Exception:
            return []

    @staticmethod
    def generate_grocery_list(recent_meals: list[str], profile: dict = None) -> list[dict]:
        profile_context = ""
        if profile:
            profile_context = f"""
            User's health profile:
            - Goal: {profile.get('goal', 'N/A')}
            - Medical Conditions: {', '.join(profile.get('medical_conditions', [])) if profile.get('medical_conditions') else 'None'}
            - Dietary Restrictions: {', '.join(profile.get('dietary_restrictions', [])) if profile.get('dietary_restrictions') else 'None'}
            """
            
        prompt = f"""
        You are an expert nutritionist. Generate a weekly grocery list for a user.
        {profile_context}
        
        User's recent logged meals are:
        {json.dumps(recent_meals)}
        
        Generate a smart grocery list of raw ingredients and healthy foods they need to buy for the upcoming week to prepare balanced meals aligned with their goal and health profile. Avoid ingredients that conflict with their dietary restrictions or medical conditions.
        
        Return ONLY a JSON array of category objects, where each object has the keys:
        - "category": string (e.g., "Produce", "Proteins", "Dairy & Alternatives", "Grains & Pantry", "Healthy Snacks")
        - "items": list of objects, each containing:
            - "name": string (the item name, e.g. "Spinach", "Avocado", "Chicken breast")
            - "quantity": string (e.g. "250g", "6 units", "1 kg")
            - "checked": boolean (always false)
        """
        try:
            response = gemini_pool.generate_content(
                model='gemini-3.7-flash',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                ),
            )
            return json.loads(response.text)
        except Exception:
            return [
                {
                    "category": "Produce",
                    "items": [
                        {"name": "Spinach", "quantity": "1 bunch", "checked": False},
                        {"name": "Bananas", "quantity": "1 dozen", "checked": False}
                    ]
                },
                {
                    "category": "Proteins",
                    "items": [
                        {"name": "Chicken Breast", "quantity": "1 kg", "checked": False},
                        {"name": "Eggs", "quantity": "1 dozen", "checked": False}
                    ]
                }
            ]
