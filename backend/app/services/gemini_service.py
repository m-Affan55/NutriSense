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
            model='gemini-3.6-flash',
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
    def evaluate_ingredients(ingredients: str, allergens: str, profile: dict = None) -> list[str]:
        if not profile:
            return []
            
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
        
        response = gemini_pool.generate_content(
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
                model='gemini-3.6-flash',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                ),
            )
            return json.loads(response.text)
        except Exception as e:
            # Safe heuristic fallback
            return {
                "name": query.title(),
                "calories": 450,
                "protein_g": 15.0,
                "carbs_g": 55.0,
                "fat_g": 18.0
            }

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
