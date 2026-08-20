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
def get_habit_score(user_id: str):
    try:
        supabase = get_supabase_admin_client()
        
        # 1. Fetch user health profile
        profile_res = supabase.table('health_profiles').select('*').eq('user_id', user_id).maybe_single().execute()
        profile = profile_res.data if hasattr(profile_res, 'data') else profile_res
        if not profile:
            raise HTTPException(status_code=404, detail="Profile not found")

        # 2. Fetch last 30 days of meals
        thirty_days_ago = (datetime.datetime.now() - datetime.timedelta(days=30)).isoformat()
        meals_res = supabase.table('meal_logs').select('*').eq('user_id', user_id).gte('logged_at', thirty_days_ago).execute()
        meals = meals_res.data

        # 3. Compute habit score components
        # (This is a simplified calculation for the hackathon)
        days_logged = len(set([m['logged_at'][:10] for m in meals])) if meals else 0
        consistency_score = min(days_logged / 30.0, 1.0) * 40.0
        
        target_cal = profile.get('daily_calorie_target', 2000)
        target_pro = profile.get('daily_protein_g', 50)
        
        cal_score = 0.0
        pro_score = 0.0
        
        # Group meals by day to calculate daily totals
        daily_totals = {}
        for m in meals:
            day = m['logged_at'][:10]
            if day not in daily_totals:
                daily_totals[day] = {'cal': 0, 'pro': 0}
            daily_totals[day]['cal'] += (m.get('total_calories') or 0)
            daily_totals[day]['pro'] += (m.get('total_protein_g') or 0)
            
        if days_logged > 0:
            cal_accuracy_sum = 0
            pro_accuracy_sum = 0
            for day, totals in daily_totals.items():
                # Calorie accuracy (within 20%)
                if abs(totals['cal'] - target_cal) / max(target_cal, 1) <= 0.2:
                    cal_accuracy_sum += 1
                # Protein met (>= 80%)
                if totals['pro'] >= target_pro * 0.8:
                    pro_accuracy_sum += 1
                    
            cal_score = (cal_accuracy_sum / days_logged) * 35.0
            pro_score = (pro_accuracy_sum / days_logged) * 25.0

        total_score = consistency_score + cal_score + pro_score
        
        # Generate trend for the last 7 weeks (simplified to last 7 days for the UI bar chart)
        trend = []
        for i in range(7):
            day_str = (datetime.datetime.now() - datetime.timedelta(days=i)).isoformat()[:10]
            if day_str in daily_totals:
                # 1.0 if logged, else 0.2 (to show a tiny bar instead of completely empty)
                trend.append(1.0)
            else:
                trend.append(0.2)
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
