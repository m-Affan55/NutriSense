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
    
    meals_context = "Meals logged recently: None."
    if meals:
        meals_context = "\nMeals logged recently:\n" + "\n".join([
            f"- {m.get('notes', 'Unnamed meal')}: {m.get('total_calories', 0)} kcal (P: {m.get('total_protein_g', 0)}g, C: {m.get('total_carbs_g', 0)}g, F: {m.get('total_fat_g', 0)}g)"
            for m in meals
        ])
        
    system_instruction = f"""
    You are an independent medical safety evaluator agent for NutriSense.
    Your job is to read the user's message, the AI Coach's reply, the user's medical conditions, and their recent food intake, and decide if there is an active 'warning' or 'critical' health risk that warrants escalation.

    User's Message: "{user_message}"
    User's Medical Conditions: {', '.join(profile.get('medical_conditions', [])) if profile.get('medical_conditions') else 'Not specified (evaluate from message)'}
    User's Dietary Restrictions: {', '.join(profile.get('dietary_restrictions', [])) if profile.get('dietary_restrictions') else 'None'}
    {meals_context}

    Coach's reply:
    \"\"\"
    {coach_reply}
    \"\"\"

    RULES:
    1. ACUTE CLINICAL RISK: If the user explicitly mentions emergency readings (blood glucose >= 300 mg/dL or < 70 mg/dL), severe dizziness, fainting, chest pain, or hypoglycemia symptoms in their message, return level="critical" or "warning" and an urgent safety warning.
    2. ACTIVE CONFLICT IN INTAKE/QUERY: If the user is currently asking to eat or currently reporting eating food that severely conflicts with their medical condition (e.g. a diabetic actively consuming high pure sugar), return level="warning".
    3. CASUAL GREETINGS & NORMAL CHAT: If the user is only greeting ("hello", "hi", etc.), asking general fitness/nutrition questions, or there is NO active clinical emergency/conflict, return level="none" and message="". Do NOT trigger warnings on conversational greetings or hypothetical coaching examples.
    4. Keep message under 30 words. DO NOT provide medical diagnoses.
    """

    try:
        response = gemini_pool.generate_content(
            contents=[system_instruction],
            model="gemini-2.5-flash",
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
        if has_acute_symptom:
            return {
                "level": "warning",
                "message": "Potential health risk detected. Please monitor your symptoms and consult a healthcare professional."
            }
        return {"level": "none", "message": ""}
