from fastapi import APIRouter, HTTPException, Response
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel, Field
from typing import List, Optional
import datetime
from app.core.config import settings
from app.db.supabase_client import get_supabase_admin_client
from app.services import tts_service
from app.services.user_cache import user_cache
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
    client_profile: Optional[dict] = None
    client_meals: Optional[List[dict]] = None

class TtsRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=3000, description="Text to speak; Markdown is stripped server-side")
    language: str = Field(default="ur", max_length=8, description="'ur' or 'en'")
    gender: str = Field(default="female", max_length=10, description="'female' or 'male'")

@router.post("/chat")
async def chat_with_coach(req: CoachRequest):
    try:
        today_str = datetime.date.today().isoformat()
        
        # 1. Fetch user health profile (Memory Cache / Client Context / Lazy Rehydration)
        if req.client_profile:
            profile = req.client_profile
            user_cache.set_profile(req.user_id, profile)
        else:
            profile = user_cache.get_profile(req.user_id)
        
        # 2. Fetch user's meals logged today (Memory Cache / Client Context / Lazy Rehydration)
        if req.client_meals is not None:
            meals = req.client_meals
            user_cache.set_today_meals(req.user_id, today_str, meals)
        else:
            meals = user_cache.get_today_meals(req.user_id, today_str)
        
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
        else:
            meals_context = "\nMeals logged today:\n- None (0 kcal consumed so far today). Do NOT invent, assume, or fabricate any meals or snacks."
            
        system_instruction = f"""
        You are an empathetic, professional, and expert AI Nutritionist & Health Coach for NutriSense.
        Your goal is to guide the user towards their nutrition and physical health objectives based on their health profile and daily intake.
        
        {profile_context}
        {meals_context}
        
        CORE GUIDELINES:
        1. GREETINGS & INTENT: If the user sends a simple greeting (e.g. "hello", "hi", "salam", "hey") or asks a general question, greet them warmly, ask how you can assist their nutrition journey today, and do NOT unpromptedly critique, lecture, or invent past food logs.
        2. ZERO-MEAL INTEGRITY: If no meals are logged today, do NOT make up or assume any foods were eaten. Only discuss meals if the user mentions them or if verified in the logged meals list above.
        3. MEDICAL PERSONALIZATION: For users with medical conditions (like Diabetes or Hypertension), keep recommendations safe (e.g., low GI carbs, balanced proteins/healthy fats for diabetes, low sodium for hypertension) whenever discussing meal choices or suggestions.
        4. Be concise, supportive, actionable, and focus on practical recommendations. Respond in English or Urdu depending on the user's input language.
        """
        
        # 4. Generate response using GeminiPool with auto-failover (non-blocking thread pool)
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
        
        response = await run_in_threadpool(
            gemini_pool.generate_content,
            contents=contents,
            model="gemini-2.5-flash-lite",
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
            ),
        )
        
        coach_reply = response.text if response and response.text else "I am here to guide your nutrition. How else can I assist?"
        
        # 5. Evaluate Health Risk (Independent agentic pass, non-blocking thread pool)
        escalation_alert = None
        from app.services.risk_evaluator import evaluate_health_risk
        risk = await run_in_threadpool(
            evaluate_health_risk,
            coach_reply,
            profile or {},
            meals or [],
            user_message=req.message
        )
        
        if risk["level"] in ("warning", "critical"):
            # Save risk flag to DB
            try:
                supabase = get_supabase_admin_client()
                await run_in_threadpool(
                    lambda: supabase.table('risk_flags').insert({
                        "user_id": req.user_id,
                        "level": risk["level"],
                        "message": risk["message"],
                        "coach_reply": coach_reply,
                        "is_resolved": False
                    }).execute()
                )
            except Exception as e:
                print(f"Failed to log risk flag to DB: {e}")
            
            escalation_alert = {
                "level": risk["level"],
                "message": risk["message"],
                "show_doctor_button": True
            }
            
            # Append safety disclaimer to avoid contradiction (Issue 14)
            disclaimer = "\n\n⚠️ Note: Based on your health profile, please review the safety alert below before following this advice."
            if disclaimer not in coach_reply:
                coach_reply += disclaimer

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


@router.post("/tts")
async def synthesize_coach_speech(req: TtsRequest):
    """Return natural neural speech (MP3) for a coach reply.

    On-device TTS engines rarely ship a usable ur-PK voice pack, so Urdu comes
    out robotic or mispronounced. This renders the reply with a Microsoft neural
    Urdu voice instead. Markdown and emoji are stripped server-side.

    A 503 here is expected and recoverable: the client falls back to on-device
    flutter_tts, so voice mode keeps working offline or if the provider is down.
    """
    try:
        audio, voice, cached = await tts_service.synthesize(
            text=req.text,
            language=req.language,
            gender=req.gender,
        )
    except tts_service.TtsUnavailable as exc:
        # 503 signals the client to use its on-device fallback.
        raise HTTPException(status_code=503, detail=str(exc))

    return Response(
        content=audio,
        media_type="audio/mpeg",
        headers={
            "Content-Length": str(len(audio)),
            "Cache-Control": "public, max-age=86400",
            "X-TTS-Voice": voice,
            "X-TTS-Cached": "1" if cached else "0",
        },
    )


@router.get("/tts/health")
async def tts_health():
    """Report provider availability and warm the connection.

    Call this on app start (and before a live demo) so the first real request
    isn't paying for a cold container plus a fresh provider handshake.
    """
    ready = await tts_service.warmup()
    return {
        "provider_installed": tts_service.EDGE_TTS_AVAILABLE,
        "ready": ready,
        "voices": tts_service.VOICES,
        "cache": tts_service.cache_stats(),
    }
