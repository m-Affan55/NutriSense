import json
from google import genai
from google.genai import types
from pydantic import BaseModel
from app.core.config import settings

class RiskEvaluationResponse(BaseModel):
    level: str  # 'none', 'warning', 'critical'
    message: str # the text to show to the user, if warning/critical

def evaluate_health_risk(coach_reply: str, profile: dict, meals: list, user_message: str = "") -> dict:
    import re
    # Heuristic fast check for acute critical symptoms in message
    msg_lower = user_message.lower()
    critical_keywords = [
        "350", "400", "500", "dizzy", "faint", "chest pain", "hypoglycemia", "severe pain", 
        "ambulance", "emergency", "بے ہوش", "چکر", "سینے میں درد",
        "low sugar", "blood sugar low", "shakiness", "shaking", "sweating", "confusion", 
        "blurred vision", "لرزنا", "شوگر کم"
    ]
    has_acute_symptom = any(k in msg_lower for k in critical_keywords)

    # Regex search for numeric blood sugar readings below 70 mg/dL (e.g. "sugar: 55")
    if not has_acute_symptom:
        glucose_match = re.search(r'(?:sugar|glucose|reading|level|value|bs|bg)\b.*?\b([1-9]\d)\b', msg_lower)
        if glucose_match:
            try:
                val = int(glucose_match.group(1))
                if 10 <= val < 70:
                    has_acute_symptom = True
            except ValueError:
                pass

    if not (profile and profile.get("medical_conditions")) and not has_acute_symptom:
        return {"level": "none", "message": ""}
        
    from app.services.gemini_pool import gemini_pool
    
    meals_context = ""
    if meals:
        meals_context = "\nMeals logged recently:\n" + "\n".join([
            f"- {m.get('notes', 'Unnamed meal')}: {m.get('total_calories', 0)} kcal (P: {m.get('total_protein_g', 0)}g, C: {m.get('total_carbs_g', 0)}g, F: {m.get('total_fat_g', 0)}g)"
            for m in meals
        ])
        
    system_instruction = f"""
    You are an independent medical safety evaluator agent for NutriSense.
    Your job is to read the user's message, the AI Coach's reply, the user's medical conditions, and their recent food intake, and decide if there is a 'warning' or 'critical' health risk that warrants escalation.

    User's Message: "{user_message}"
    User's Medical Conditions: {', '.join(profile.get('medical_conditions', [])) if profile.get('medical_conditions') else 'Not specified (evaluate from message)'}
    User's Dietary Restrictions: {', '.join(profile.get('dietary_restrictions', [])) if profile.get('dietary_restrictions') else 'None'}
    {meals_context}

    Coach's reply:
    \"\"\"
    {coach_reply}
    \"\"\"

    RULES:
    1. If the user mentions very high/low blood glucose (e.g. >= 300 mg/dL), severe dizziness, or chest tightness, return level="critical" or "warning" and an urgent safety warning.
    2. If there is a pattern of poor choices that conflict with their medical condition (e.g. high sugar for a diabetic, high sodium for hypertension), return level="warning".
    3. If there is NO conflict, return level="none" and message="".
    4. Keep message under 30 words. DO NOT provide medical diagnoses.
    """

    try:
        response = gemini_pool.generate_content(
            contents=[system_instruction],
            model="gemini-3.6-flash",
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=RiskEvaluationResponse,
            ),
        )
        data = json.loads(response.text)
        level = data.get("level", "none").lower()
        if level not in ["none", "warning", "critical"]:
            level = "none"
        return {
            "level": level,
            "message": data.get("message", "")
        }
    except Exception as e:
        print(f"Risk Evaluator Error: {str(e)}")
        if has_acute_symptom or (profile and profile.get("medical_conditions")):
            return {
                "level": "warning",
                "message": "Potential health risk or conflict detected. Please monitor your symptoms and consult a healthcare professional."
            }
        return {"level": "none", "message": ""}
