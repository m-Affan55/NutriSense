from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
import datetime
from app.db.supabase_client import get_supabase_admin_client
from app.services.gemini_service import GeminiService

router = APIRouter()

class SwapRequest(BaseModel):
    user_id: str
    recent_meals: List[str]

@router.get("/habit-score/{user_id}")
def get_habit_score(user_id: str, offset_minutes: int = 0):
    try:
        supabase = get_supabase_admin_client()
        
        # 1. Fetch user health profile
        profile_res = supabase.table('health_profiles').select('*').eq('user_id', user_id).maybe_single().execute()
        profile = profile_res.data if hasattr(profile_res, 'data') else profile_res
        if not profile:
            profile = {
                'daily_calorie_target': 2000,
                'daily_protein_g': 50,
                'goal': 'General Health & Wellness',
                'medical_conditions': [],
                'dietary_restrictions': []
            }

        # 2. Fetch last 30 days of meals (Using UTC to match Supabase TIMESTAMPTZ correctly)
        now_utc = datetime.datetime.now(datetime.timezone.utc)
        thirty_days_ago = (now_utc - datetime.timedelta(days=30)).isoformat()
        meals_res = supabase.table('meal_logs').select('*').eq('user_id', user_id).gte('logged_at', thirty_days_ago).execute()
        meals = meals_res.data or []

        # 3. Compute habit score components
        target_cal = profile.get('daily_calorie_target', 2000)
        target_pro = profile.get('daily_protein_g', 50)
        
        # Define user timezone from offset_minutes (negative offset means behind UTC, positive means ahead)
        tz = datetime.timezone(datetime.timedelta(minutes=offset_minutes))
        now_local = now_utc.astimezone(tz)
        
        # Group meals by user local day to calculate daily totals
        daily_totals = {}
        for m in meals:
            try:
                logged_at_str = m['logged_at'].replace('Z', '+00:00')
                dt_utc = datetime.datetime.fromisoformat(logged_at_str)
                dt_local = dt_utc.astimezone(tz)
                day = dt_local.date().isoformat()
            except Exception:
                day = m['logged_at'][:10]
                
            if day not in daily_totals:
                daily_totals[day] = {'cal': 0, 'pro': 0}
            daily_totals[day]['cal'] += (m.get('total_calories') or 0)
            daily_totals[day]['pro'] += (m.get('total_protein_g') or 0)
            
        days_logged = len(daily_totals)
        consistency_score = min(days_logged / 30.0, 1.0) * 40.0
        
        cal_score = 0.0
        pro_score = 0.0
        
        if days_logged > 0:
            cal_accuracy_sum = 0
            pro_accuracy_sum = 0
            for day, totals in daily_totals.items():
                if abs(totals['cal'] - target_cal) / max(target_cal, 1) <= 0.2:
                    cal_accuracy_sum += 1
                if totals['pro'] >= target_pro * 0.8:
                    pro_accuracy_sum += 1
                    
            cal_score = (cal_accuracy_sum / days_logged) * 35.0
            pro_score = (pro_accuracy_sum / days_logged) * 25.0

        total_score = consistency_score + cal_score + pro_score
        
        # Generate trend for the last 7 days (Daily Adherence Score or -1.0 if missing)
        trend = []
        for i in range(7):
            day_str = (now_local - datetime.timedelta(days=i)).date().isoformat()
            if day_str in daily_totals:
                totals = daily_totals[day_str]
                day_cal_acc = 1.0 if abs(totals['cal'] - target_cal) / max(target_cal, 1) <= 0.2 else 0.0
                day_pro_acc = 1.0 if totals['pro'] >= target_pro * 0.8 else 0.0
                daily_adherence = (day_cal_acc * 0.58) + (day_pro_acc * 0.42)
                # Ensure it's never 0.0 otherwise it might look empty when they did log, return at least 0.1
                trend.append(max(daily_adherence, 0.1))
            else:
                trend.append(-1.0)
        trend.reverse()
        
        # 4. Get Gemini coaching summary
        summary = GeminiService.generate_coaching_summary(total_score, profile)
        
        return {
            "score": round(total_score),
            "trend": trend,
            "coaching_message": summary
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/food-swaps")
def get_food_swaps(req: SwapRequest):
    try:
        supabase = get_supabase_admin_client()
        
        # Fetch user health profile
        profile_res = supabase.table('health_profiles').select('*').eq('user_id', req.user_id).maybe_single().execute()
        profile = profile_res.data if hasattr(profile_res, 'data') else profile_res
        
        swaps = GeminiService.generate_food_swaps(req.recent_meals, profile)
        
        return {"swaps": swaps}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
