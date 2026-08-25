from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import List
from app.core.config import settings
from app.db.supabase_client import get_supabase_admin_client
from google import genai
from google.genai import types

router = APIRouter()

class ChatMessage(BaseModel):
    role: str = Field(..., max_length=20)
    content: str = Field(..., max_length=5000)

class CoachRequest(BaseModel):
    user_id: str = Field(..., min_length=1, max_length=128)
    message: str = Field(..., min_length=1, max_length=3000, description="Chat message limited to 3000 characters")
    history: List[ChatMessage] = Field(default_factory=list)

@router.post("/chat")
def chat_with_coach(req: CoachRequest):
    try:
        supabase = get_supabase_admin_client()
        
        # 1. Fetch user health profile
        profile_res = supabase.table('health_profiles').select('*').eq('user_id', req.user_id).maybe_single().execute()
        profile = profile_res.data
        
        # 2. Fetch user's meals logged today
        import datetime
        today_str = datetime.date.today().isoformat()
        meals_res = supabase.table('meal_logs').select('*').eq('user_id', req.user_id).gte('logged_at', f"{today_str}T00:00:00").lte('logged_at', f"{today_str}T23:59:59").execute()
        meals = meals_res.data
        
        # 3. Formulate the system instruction
        profile_context = ""
        if profile:
            profile_context = f"""
            User Profile:
            - Age: {profile.get('age', 'N/A')}
            - Goal: {profile.get('goal', 'N/A')}
            - Daily Calorie Target: {profile.get('daily_calorie_target', 2000)} kcal
            - Macros target: Protein {profile.get('daily_protein_g', 130)}g, Carbs {profile.get('daily_carbs_g', 220)}g, Fat {profile.get('daily_fat_g', 65)}g
            - Medical Conditions: {', '.join(profile.get('medical_conditions', [])) if profile.get('medical_conditions') else 'None'}
            - Dietary Restrictions: {', '.join(profile.get('dietary_restrictions', [])) if profile.get('dietary_restrictions') else 'None'}
            """
            
        meals_context = ""
        if meals:
            meals_context = "\nMeals logged today:\n" + "\n".join([
                f"- {m.get('notes', 'Unnamed meal')}: {m.get('total_calories', 0)} kcal (P: {m.get('total_protein_g', 0)}g, C: {m.get('total_carbs_g', 0)}g, F: {m.get('total_fat_g', 0)}g)"
                for m in meals
            ])
            
        system_instruction = f"""
        You are an empathetic, professional, and expert AI Nutritionist & Health Coach for NutriSense.
        Your goal is to guide the user towards their nutrition and physical health objectives based on their health profile and daily intake.
        
        {profile_context}
        {meals_context}
        
        Be concise, supportive, actionable, and focus on practical recommendations. Respond in English or Urdu depending on the user's input language.
        """
        
        # 4. Generate response using GeminiPool with auto-failover
        from app.services.gemini_pool import gemini_pool
        
        # Convert bounded history (last 20 messages max) to format compatible with GenAI content list
        contents = []
        bounded_history = req.history[-20:] if req.history else []
        for msg in bounded_history:
            contents.append({
                "role": "user" if msg.role == "user" else "model",
                "parts": [{"text": msg.content}]
            })
            
        # Add the current user message
        contents.append({
            "role": "user",
            "parts": [{"text": req.message}]
        })
        
        response = gemini_pool.generate_content(
            contents=contents,
            model="gemini-3.6-flash",
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
            ),
        )
        
        coach_reply = response.text if response and response.text else "I am here to guide your nutrition. How else can I assist?"
        
        # 5. Evaluate Health Risk (Independent agentic pass)
        escalation_alert = None
        from app.services.risk_evaluator import evaluate_health_risk
        risk = evaluate_health_risk(coach_reply, profile or {}, meals or [], user_message=req.message)
        
        if risk["level"] in ("warning", "critical"):
            # Save risk flag to DB
            try:
                supabase.table('risk_flags').insert({
                    "user_id": req.user_id,
                    "level": risk["level"],
                    "message": risk["message"],
                    "coach_reply": coach_reply,
                    "is_resolved": False
                }).execute()
            except Exception as e:
                print(f"Failed to log risk flag to DB: {e}")
            
            escalation_alert = {
                "level": risk["level"],
                "message": risk["message"],
                "show_doctor_button": True
            }

        return {"response": coach_reply, "escalation_alert": escalation_alert}
        
    except Exception as e:
        print(f"Chat error: {e}")
        # Graceful emergency fallback if network/quota fails across all keys
        msg_lower = req.message.lower()
        critical_keywords = ["350", "400", "500", "dizzy", "faint", "chest pain", "hypoglycemia", "severe pain", "ambulance", "emergency", "بے ہوش", "چکر", "سینے میں درد"]
        has_acute = any(k in msg_lower for k in critical_keywords)
        
        if has_acute:
            emergency_msg = "Please note: If you are experiencing unusual dizziness, severe fatigue, or extreme blood sugar fluctuations, please hydrate with plain water and consult a qualified physician immediately."
            escalation = {
                "level": "warning",
                "message": "Potential health risk detected. Please seek medical advice.",
                "show_doctor_button": True
            }
            return {"response": emergency_msg, "escalation_alert": escalation}
        else:
            return {"response": "I am experiencing technical difficulties right now. Please try again in a few moments.", "escalation_alert": None}
