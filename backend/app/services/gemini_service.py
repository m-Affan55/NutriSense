import base64
import json
from google import genai
from google.genai import types
from app.core.config import settings
from app.schemas.meal import MealScanResponse

class GeminiService:
    @staticmethod
    def scan_meal(image_bytes: bytes, mime_type: str, profile: dict = None) -> dict:
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        
        profile_context = ""
        if profile:
            profile_context = f"""
            The user's health profile:
            - Age: {profile.get('age', 'N/A')}
            - Goal: {profile.get('goal', 'N/A')}
            - Daily Calorie Target: {profile.get('daily_calorie_target', 'N/A')} kcal
            - Medical Conditions: {', '.join(profile.get('medical_conditions', [])) if profile.get('medical_conditions') else 'None'}
            - Dietary Restrictions: {', '.join(profile.get('dietary_restrictions', [])) if profile.get('dietary_restrictions') else 'None'}
            """
            
        DESI_FOOD_CONTEXT = """
        IMPORTANT: This app is used primarily in Pakistan. You will frequently encounter 
        South Asian / Pakistani dishes. Apply these rules:

        PORTION SIZES (Pakistani context):
        - 1 katori (small bowl) ≈ 150-200g for curries/dal
        - 1 roti (chapati) ≈ 35-40g, naan ≈ 90g, paratha ≈ 100-130g (oiled)
        - 1 serving biryani ≈ 300-350g
        - 1 glass lassi ≈ 250ml

        COOKING METHOD ADJUSTMENTS:
        - Pakistani curries: add 15-25% extra fat calories for ghee/oil used in tarka
        - Desi breakfast items (halwa puri, nihari): significantly higher fat content
        - Roti/chapati: if appears oiled or is paratha, increase fat estimate accordingly

        COMMON PAKISTANI DISHES - use these as nutritional benchmarks:
        - Daal (lentils, any type): ~120 kcal/katori, 7g protein, 18g carbs, 3g fat (add tarka fat)
        - Bhindi (okra curry): ~80 kcal/katori, 2g protein, 9g carbs, 4g fat
        - Biryani (chicken): ~350 kcal/serving, 18g protein, 45g carbs, 10g fat
        - Karahi (chicken/mutton): ~280 kcal/serving, 22g protein, 8g carbs, 18g fat
        - Nihari: ~380 kcal/serving, 28g protein, 12g carbs, 25g fat
        - Saag: ~150 kcal/katori, 6g protein, 12g carbs, 9g fat
        - Halwa Puri (1 set): ~600 kcal total, 12g protein, 75g carbs, 28g fat
        - Roti (plain): ~90 kcal, 3g protein, 18g carbs, 1.5g fat
        - Paratha (oiled): ~200 kcal, 4g protein, 24g carbs, 9g fat
        - Kheer: ~200 kcal/katori, 5g protein, 35g carbs, 5g fat
        - Dahi (yogurt, plain): ~60 kcal/katori, 4g protein, 6g carbs, 2g fat

        If you identify a Pakistani dish not in the above list, estimate macros based on 
        its primary ingredients and cooking method, erring on the side of slight overestimation
        for fat content due to typical Pakistani cooking.
        """
        
        prompt = f"""
        Analyze the uploaded photo of a meal.
        {profile_context}
        {DESI_FOOD_CONTEXT}
        
        CRITICAL RULES — FOLLOW THESE STRICTLY:
        
        RULE 1 — ONLY IDENTIFY WHAT IS VISIBLE:
        Do NOT guess or hallucinate items that are not clearly visible in the photo.
        If you see ONE dish in ONE bowl, report exactly ONE item. Do NOT add side 
        dishes (roti, dahi, raita, naan, salad, etc.) unless they are CLEARLY AND 
        VISIBLY present in the image. If you can only see a curry in a bowl with no 
        bread visible, do NOT add roti/naan. This is the #1 most important rule.
        
        RULE 2 — HONESTY OVER CONFIDENCE:
        Set `recognition_confidence` to "low" if ANY of these are true:
        - The dish is a brown/dark curry where you cannot clearly distinguish the 
          protein source (e.g. could be chicken OR mutton OR beef)
        - The image is blurry, dark, or taken at an angle that obscures the food
        - You are choosing between 2+ possible identifications
        - The dish is submerged in gravy/sauce making ingredients hard to see
        Only set "high" if you are >90% certain of the EXACT dish name.

        
        Now perform the following:
        1. Identify ONLY the food items CLEARLY VISIBLE on the plate/bowl. For each 
           item, provide the English `name` and the Urdu `local_name`. Provide a 
           `cooking_method_note` explaining any fat/calorie adjustments made.
        2. Estimate the portions and weights in grams.
        3. Calculate the calories and macronutrients (protein_g, carbs_g, fat_g) for 
           each item and the total meal.
        4. Set `recognition_confidence` per RULE 2 above.
        5. Cross-reference the identified ingredients against the user's medical 
           conditions and dietary restrictions to generate safety warnings if any 
           conflict occurs.
        6. Provide helpful coaching suggestions matching their goal.
        """
        
        response = client.models.generate_content(
            model='gemini-3.6-flash',
            contents=[
                types.Part.from_bytes(
                    data=image_bytes,
                    mime_type=mime_type
                ),
                prompt
            ],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=MealScanResponse,
            ),
        )
        
        try:
            return json.loads(response.text)
        except Exception as e:
            return {
                "meal_name": "Scanned Meal",
                "items": [],
                "total_calories": 0,
                "total_protein_g": 0.0,
                "total_carbs_g": 0.0,
                "total_fat_g": 0.0,
                "recognition_confidence": "low",
                "health_warnings": [f"Parsing error: {str(e)}"],
                "suggestions": ["Could not parse structured nutrition details. Please try again."]
            }

    @staticmethod
    def evaluate_ingredients(ingredients: str, allergens: str, profile: dict = None) -> list[str]:
        if not profile:
            return []
            
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        
        prompt = f"""
        You are an expert nutritionist and medical safety evaluator.
        
        The user has scanned a packaged food product with the following details:
        Ingredients: {ingredients}
        Listed Allergens: {allergens}
        
        The user's health profile is:
        - Medical Conditions: {', '.join(profile.get('medical_conditions', [])) if profile.get('medical_conditions') else 'None'}
        - Dietary Restrictions: {', '.join(profile.get('dietary_restrictions', [])) if profile.get('dietary_restrictions') else 'None'}
        
        Task:
        Analyze the ingredients and allergens against the user's health profile.
        If there are ANY dangerous conflicts (e.g., the product contains peanuts and the user has a peanut allergy, or the product is high in sugar and the user is diabetic), list the specific warnings.
        If there are no conflicts, return an empty list.
        
        Return ONLY a JSON array of strings representing the warnings. Examples:
        ["CRITICAL: This product contains peanuts, which conflicts with your Peanut Allergy!"]
        ["WARNING: Contains added sugars (fructose), which may not be suitable for your Diabetes."]
        []
        """
        
        response = client.models.generate_content(
            model='gemini-3.6-flash',
            contents=[prompt],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
            ),
        )
        
        try:
            return json.loads(response.text)
        except Exception:
            return []
