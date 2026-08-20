import base64
import json
from google import genai
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
        """
        
        interaction = client.interactions.create(
            model="gemini-3.6-flash",
            input=[
                prompt,
                {
                    "type": "image",
                    "data": base64.b64encode(image_bytes).decode('utf-8'),
                    "mime_type": mime_type
                }
            ],
            response_format={
                "type": "text",
                "mime_type": "application/json",
                "schema": MealScanResponse.model_json_schema(),
            },
        )
        
        try:
            return json.loads(interaction.output_text)
        except Exception as e:
            return {
                "meal_name": "Scanned Meal",
                "items": [],
                "total_calories": 0,
                "total_protein_g": 0.0,
                "total_carbs_g": 0.0,
                "total_fat_g": 0.0,
                "health_warnings": [f"Parsing error: {str(e)}"],
                "suggestions": ["Could not parse structured nutrition details. Please try again."]
            }
