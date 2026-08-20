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
            
        prompt = f"""
        Analyze the uploaded photo of a meal.
        {profile_context}
        Perform the following:
        1. Identify all food items visible on the plate.
        2. Estimate the portions and weights in grams.
        3. Calculate the calories and macronutrients (protein_g, carbs_g, fat_g in grams) for each item and the total meal.
        4. Cross-reference the identified ingredients against the user's medical conditions (e.g. high sodium for blood pressure, sugar content for diabetes) and dietary restrictions (e.g. vegetarian, halal) to generate safety warnings if any conflict occurs.
        5. Provide helpful coaching suggestions matching their goal (e.g. fat loss, muscle gain).
        Note: The schema requires a recognition_confidence (high/low), local_name, and cooking_method_note. Provide reasonable values.
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

    @staticmethod
    def estimate_food_macros(query: str) -> dict:
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        
        prompt = f"""
        You are an expert nutritionist database. 
        The user searched for the following food item: "{query}".
        
        Task:
        Estimate the nutritional breakdown for a standard 1-serving portion of this food.
        If the query is ambiguous, make a reasonable assumption for a standard serving.
        
        Return ONLY a JSON object with the following exact keys:
        - "name": A standardized, clear name for the food (e.g., "White Rice (1 cup)").
        - "calories": Integer
        - "protein_g": Float
        - "carbs_g": Float
        - "fat_g": Float
        """
        
        try:
            response = client.models.generate_content(
                model='gemini-3.6-flash',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                ),
            )
            return json.loads(response.text)
        except Exception as e:
            return {
                "name": query,
                "calories": 0,
                "protein_g": 0.0,
                "carbs_g": 0.0,
                "fat_g": 0.0
            }
