import json
import re
from google.genai import types
from pydantic import BaseModel
from app.services.gemini_pool import gemini_pool, MODEL_CLINICAL_JSON


class RiskEvaluationResponse(BaseModel):
    level: str    # 'none', 'warning', 'critical'
    message: str  # text to show user, if warning/critical


def evaluate_health_risk(
    coach_reply: str,
    profile: dict,
    meals: list,
    user_message: str = "",
) -> dict:
    """
    Independently evaluates whether the user's message or recent meal intake
    represents an active clinical risk, returning a severity level and message.
    """
    # Heuristic fast-check for acute critical symptoms in the user's message
    msg_lower = user_message.lower()
    critical_keywords = [
        "350", "400", "500", "dizzy", "faint", "chest pain", "hypoglycemia", "severe pain",
        "ambulance", "emergency", "بے ہوش", "چکر", "سینے میں درد",
        "low sugar", "blood sugar low", "shakiness", "shaking", "sweating", "confusion",
        "blurred vision", "لرزنا", "شوگر کم",
    ]
    has_acute_symptom = any(k in msg_lower for k in critical_keywords)

    # Regex: numeric blood sugar readings below 70 mg/dL (e.g. "sugar: 55")
    if not has_acute_symptom:
        glucose_match = re.search(
            r'(?:sugar|glucose|reading|level|value|bs|bg)\b.*?\b([1-9]\d)\b', msg_lower
        )
        if glucose_match:
            try:
                val = int(glucose_match.group(1))
                if 10 <= val < 70:
                    has_acute_symptom = True
            except ValueError:
                pass

    # Skip AI call if no medical conditions and no acute symptom detected
    if not (profile and profile.get("medical_conditions")) and not has_acute_symptom:
        return {"level": "none", "message": ""}

    meals_context = "Meals logged recently: None."
    if meals:
        meals_context = "\nMeals logged recently:\n" + "\n".join([
            f"- {m.get('notes', 'Unnamed meal')}: {m.get('total_calories', 0)} kcal "
            f"(P: {m.get('total_protein_g', 0)}g, C: {m.get('total_carbs_g', 0)}g, "
            f"F: {m.get('total_fat_g', 0)}g)"
            for m in meals
        ])

    system_instruction = f"""
    You are an independent medical safety evaluator agent for NutriSense.
    Your job is to read the user's message, the AI Coach's reply, the user's medical conditions,
    and their recent food intake, and decide if there is an active 'warning' or 'critical' health
    risk that warrants escalation.

    User's Message: "{user_message}"
    User's Medical Conditions: {', '.join(profile.get('medical_conditions', [])) if profile.get('medical_conditions') else 'Not specified (evaluate from message)'}
    User's Dietary Restrictions: {', '.join(profile.get('dietary_restrictions', [])) if profile.get('dietary_restrictions') else 'None'}
    {meals_context}

    Coach's reply:
    \"\"\"
    {coach_reply}
    \"\"\"

    RULES:
    1. ACUTE CLINICAL RISK: If the user explicitly mentions emergency readings (blood glucose >= 300 mg/dL
       or < 70 mg/dL), severe dizziness, fainting, chest pain, or hypoglycemia symptoms, return
       level="critical" or "warning" with an urgent safety warning.
    2. ACTIVE CONFLICT IN INTAKE/QUERY: If the user is reporting eating food that severely conflicts
       with their medical condition (e.g. a diabetic consuming high pure sugar), return level="warning".
    3. CASUAL GREETINGS & NORMAL CHAT: If the user is only greeting or asking general questions
       with NO active clinical emergency or conflict, return level="none" and message="".
    4. Keep message under 30 words. DO NOT provide medical diagnoses.
    """

    try:
        response = gemini_pool.generate_content(
            contents=[system_instruction],
            model=MODEL_CLINICAL_JSON,
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
            "message": data.get("message", ""),
        }
    except Exception as e:
        print(f"Risk Evaluator Error: {str(e)}")
        if has_acute_symptom:
            return {
                "level": "warning",
                "message": "Potential health risk detected. Please monitor your symptoms and consult a healthcare professional.",
            }
        return {"level": "none", "message": ""}

