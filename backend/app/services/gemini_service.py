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
            raise RuntimeError(f"Failed to parse meal scan results. Please try again. Detailed error: {str(e)}")

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

    @staticmethod
    def generate_coaching_summary(score: float, profile: dict = None) -> str:
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        
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
            response = client.models.generate_content(
                model='gemini-3.6-flash',
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
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        
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
            response = client.models.generate_content(
                model='gemini-3.6-flash',
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
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        
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
            response = client.models.generate_content(
                model='gemini-3.6-flash',
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

