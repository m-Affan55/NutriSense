from fastapi import APIRouter, File, UploadFile, Form, HTTPException
from pydantic import BaseModel
from app.services.gemini_service import GeminiService
from app.services.barcode_service import BarcodeService
from app.db.supabase_client import get_supabase_admin_client

router = APIRouter()

@router.post("/scan")
async def scan_meal(
    image: UploadFile = File(...),
    user_id: str = Form(...)
):
    try:
        # 1. Fetch user's health profile to get conditions and allergies context
        supabase = get_supabase_admin_client()
        profile_response = supabase.table('health_profiles').select('*').eq('user_id', user_id).maybe_single().execute()
        profile = profile_response.data
        
        # 2. Read image details
        image_bytes = await image.read()
        mime_type = image.content_type or "image/jpeg"
        
        # 3. Analyze plate using Gemini interactions service
        scan_result = GeminiService.scan_meal(
            image_bytes=image_bytes,
            mime_type=mime_type,
            profile=profile
        )
        
        return scan_result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class BarcodeRequest(BaseModel):
    barcode: str
    user_id: str

@router.post("/scan-barcode")
async def scan_barcode(req: BarcodeRequest):
    try:
        # 1. Fetch user's health profile
        supabase = get_supabase_admin_client()
        profile_response = supabase.table('health_profiles').select('*').eq('user_id', req.user_id).maybe_single().execute()
        profile = profile_response.data
        
        # 2. Fetch product data from OpenFoodFacts
        product_data = await BarcodeService.fetch_product_data(req.barcode)
        
        # 3. Check for allergies using Gemini
        warnings = GeminiService.evaluate_ingredients(
            ingredients=product_data["ingredients"],
            allergens=product_data["allergens"],
            profile=profile
        )
        
        return {
            "product": product_data,
            "allergy_warnings": warnings
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/weekly-report")
def get_weekly_report(user_id: str):
    try:
        supabase = get_supabase_admin_client()
        
        # 1. Fetch profile
        profile_res = supabase.table('health_profiles').select('*').eq('user_id', user_id).maybe_single().execute()
        profile = profile_res.data
        
        # 2. Fetch past 7 days of logs
        import datetime
        end_date = datetime.date.today()
        start_date = end_date - datetime.timedelta(days=7)
        
        meals_res = supabase.table('meal_logs').select('*').eq('user_id', user_id).gte('logged_at', f"{start_date.isoformat()}T00:00:00").lte('logged_at', f"{end_date.isoformat()}T23:59:59").execute()
        meals = meals_res.data
        
        water_res = supabase.table('water_logs').select('*').eq('user_id', user_id).gte('logged_at', f"{start_date.isoformat()}T00:00:00").lte('logged_at', f"{end_date.isoformat()}T23:59:59").execute()
        water = water_res.data
        
        # 3. Formulate prompts
        profile_context = ""
        if profile:
            profile_context = f"""
            User Health Target & Profile:
            - Goal: {profile.get('goal', 'maintenance')}
            - Daily Calorie Target: {profile.get('daily_calorie_target', 2000)} kcal
            - Daily Budget: {profile.get('daily_budget_pkr', 1500)} PKR
            - Medical Conditions: {profile.get('medical_conditions', [])}
            - Dietary Restrictions: {profile.get('dietary_restrictions', [])}
            """
            
        history_context = "Meal Intake Log (Last 7 Days):\n"
        if meals:
            for m in meals:
                history_context += f"- Logged at {m.get('logged_at')[:10]}: {m.get('notes', 'Meal')}, {m.get('total_calories', 0)} kcal, P: {m.get('total_protein_g', 0)}g, C: {m.get('total_carbs_g', 0)}g, F: {m.get('total_fat_g', 0)}g\n"
        else:
            history_context += "No meals logged.\n"
            
        history_context += "\nHydration Log (Last 7 Days):\n"
        if water:
            for w in water:
                history_context += f"- Logged at {w.get('logged_at')[:10]}: {w.get('amount_ml', 0)} ml\n"
        else:
            history_context += "No water logged.\n"
            
        prompt = f"""
        Analyze the user's nutritional intake for the past 7 days.
        {profile_context}
        {history_context}
        
        Please produce a structured JSON response with the following format:
        {{
            "weekly_summary": "A friendly, expert nutrition summary summarizing progress, detailing if they met calories/macro targets, stayed within their budget limit (in PKR), commented on medical warnings (like sodium/sugar checkups for diabetes/blood pressure if applicable), and gave suggestions for next week.",
            "health_score": <an integer between 0 and 100 representing their adherence and diet quality>,
            "days_adhered": <an integer from 0 to 7 of days they met their calorie/macro goals>
        }}
        
        Ensure your markdown text inside weekly_summary uses simple English or Urdu depending on user preferences, and doesn't contain any other languages.
        """
        
        from app.core.config import settings
        from google import genai
        from google.genai import types
        import json
        
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        response = client.models.generate_content(
            model="gemini-3.6-flash",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
            ),
        )
        
        return json.loads(response.text)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
