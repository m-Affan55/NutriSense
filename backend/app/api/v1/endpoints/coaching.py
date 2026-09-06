from fastapi import APIRouter, HTTPException, Depends
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel
from typing import List, Optional
import datetime
from app.db.supabase_client import get_supabase_admin_client
from app.services.gemini_service import GeminiService
from app.core.security import get_current_user_id

router = APIRouter()

class SwapRequest(BaseModel):
    user_id: str
    recent_meals: List[str]
    language: str = "en"
    family_member_id: Optional[str] = None

@router.get("/habit-score/{user_id}")
async def get_habit_score(
    user_id: str,
    offset_minutes: int = 0,
    language: str = "en",
    authenticated_user_id: str = Depends(get_current_user_id)
):
    if user_id != authenticated_user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You do not own this resource")

    try:
        supabase = get_supabase_admin_client()
        
        # 1. Fetch user health profile (non-blocking thread pool)
        profile_res = await run_in_threadpool(
            lambda: supabase.table('health_profiles').select('*').eq('user_id', user_id).maybe_single().execute()
        )
        profile = profile_res.data if hasattr(profile_res, 'data') else profile_res
        if not profile:
            profile = {
                'daily_calorie_target': 2000,
                'daily_protein_g': 50,
                'goal': 'General Health & Wellness',
                'medical_conditions': [],
                'dietary_restrictions': []
            }

        # 2. Fetch last 30 days of meals (non-blocking thread pool)
        now_utc = datetime.datetime.now(datetime.timezone.utc)
        thirty_days_ago = (now_utc - datetime.timedelta(days=30)).isoformat()
        meals_res = await run_in_threadpool(
            lambda: supabase.table('meal_logs').select('*').eq('user_id', user_id).gte('logged_at', thirty_days_ago).execute()
        )
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
        
        # 4. Get Gemini coaching summary (non-blocking thread pool)
        summary = await run_in_threadpool(GeminiService.generate_coaching_summary, total_score, profile, language)
        
        return {
            "score": round(total_score),
            "trend": trend,
            "coaching_message": summary
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/food-swaps")
async def get_food_swaps(req: SwapRequest, authenticated_user_id: str = Depends(get_current_user_id)):
    if req.user_id != authenticated_user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You do not own this resource")

    try:
        supabase = get_supabase_admin_client()
        
        profile = None
        if req.family_member_id:
            fam_res = await run_in_threadpool(
                lambda: supabase.table('family_members').select('*').eq('id', req.family_member_id).maybe_single().execute()
            )
            fam_data = fam_res.data if hasattr(fam_res, 'data') else fam_res
            if fam_data:
                profile = {
                    'goal': 'General Family Health',
                    'medical_conditions': fam_data.get('medical_conditions', []),
                    'dietary_restrictions': fam_data.get('dietary_restrictions', []),
                }

        if not profile:
            # Fetch user health profile (non-blocking thread pool)
            profile_res = await run_in_threadpool(
                lambda: supabase.table('health_profiles').select('*').eq('user_id', req.user_id).maybe_single().execute()
            )
            profile = profile_res.data if hasattr(profile_res, 'data') else profile_res
        
        # Generate food swaps (non-blocking thread pool)
        result = await run_in_threadpool(GeminiService.generate_food_swaps, req.recent_meals, profile, req.language)
        
        if isinstance(result, dict):
            swaps_list = result.get("swaps", [])
            is_healthy = result.get("is_healthy", len(swaps_list) == 0)
            return {
                "is_healthy": bool(is_healthy),
                "message": str(result.get("message", "")),
                "swaps": swaps_list
            }
        elif isinstance(result, list):
            return {
                "is_healthy": len(result) == 0,
                "message": "",
                "swaps": result
            }
        return {"is_healthy": True, "message": "", "swaps": []}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
