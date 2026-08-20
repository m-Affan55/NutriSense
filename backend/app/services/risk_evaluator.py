import json
from google import genai
from google.genai import types
from pydantic import BaseModel
from app.core.config import settings

class RiskEvaluationResponse(BaseModel):
    level: str  # 'none', 'warning', 'critical'
    message: str # the text to show to the user, if warning/critical

def evaluate_health_risk(coach_reply: str, profile: dict, meals: list) -> dict:
    if not profile or not profile.get("medical_conditions"):
        return {"level": "none", "message": ""}
        
    client = genai.Client(api_key=settings.GEMINI_API_KEY)
    
    meals_context = ""
    if meals:
        meals_context = "\nMeals logged recently:\n" + "\n".join([
            f"- {m.get('notes', 'Unnamed meal')}: {m.get('total_calories', 0)} kcal (P: {m.get('total_protein_g', 0)}g, C: {m.get('total_carbs_g', 0)}g, F: {m.get('total_fat_g', 0)}g)"
            for m in meals
        ])
        
    system_instruction = f"""
    You are an independent medical safety evaluator agent for NutriSense.
    Your job is to read the AI Coach's generated reply, the user's medical conditions, and their recent food intake, and decide if there is a 'warning' or 'critical' health risk that warrants escalation.

    User's Medical Conditions: {', '.join(profile.get('medical_conditions', []))}
    User's Dietary Restrictions: {', '.join(profile.get('dietary_restrictions', [])) if profile.get('dietary_restrictions') else 'None'}
    {meals_context}

    Coach's reply to evaluate:
    \"\"\"
    {coach_reply}
    \"\"\"

    RULES:
    1. If there is NO direct conflict with their medical conditions, return level="none" and message="".
    2. If there is a pattern of poor choices that conflict with their medical condition (e.g. high sugar for a diabetic, high sodium for hypertension), return level="warning" and a concise message (under 30 words) suggesting they consult a professional.
    3. If there is a severe, immediate risk (e.g. allergic reaction), return level="critical" and a strong message.
    4. DO NOT provide medical diagnoses.
    """

    response = client.models.generate_content(
        model="gemini-3.6-flash",
        contents=[system_instruction],
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=RiskEvaluationResponse,
        ),
    )
    
    try:
        data = json.loads(response.text)
        level = data.get("level", "none").lower()
        if level not in ["none", "warning", "critical"]:
            level = "none"
        return {
            "level": level,
            "message": data.get("message", "")
        }
    except Exception:
        return {"level": "none", "message": ""}
