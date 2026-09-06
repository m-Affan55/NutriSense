from fastapi import APIRouter, HTTPException, Depends
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel
from typing import Optional
from app.db.supabase_client import get_supabase_admin_client
from app.services.gemini_service import GeminiService
from app.services.user_cache import user_cache
from app.core.security import get_current_user_id

router = APIRouter()

class HealthSyncInsightRequest(BaseModel):
    user_id: str
    steps: int = 0
    step_goal: int = 10000
    active_kcal: int = 0
    sleep_hours: float = 0.0
    heart_rate: int = 0
    source: Optional[str] = "Health Connect"
    language: str = "en"
    family_member_id: Optional[str] = None

@router.post("/ai-insight")
async def get_health_sync_insight(
    req: HealthSyncInsightRequest,
    authenticated_user_id: str = Depends(get_current_user_id)
):
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
            # Always query fresh profile from health_profiles to ensure real-time medical conditions
            profile_res = await run_in_threadpool(
                lambda: supabase.table('health_profiles').select('*').eq('user_id', req.user_id).maybe_single().execute()
            )
            profile = profile_res.data if hasattr(profile_res, 'data') else profile_res
            if profile:
                user_cache.get_instance().set_profile(req.user_id, profile)

        activity_data = {
            "steps": req.steps,
            "step_goal": req.step_goal,
            "active_kcal": req.active_kcal,
            "sleep_hours": req.sleep_hours,
            "heart_rate": req.heart_rate,
            "source": req.source,
        }

        # Run clinical AI insight generation non-blocking in threadpool
        result = await run_in_threadpool(
            GeminiService.generate_health_sync_insight,
            activity_data,
            profile,
            req.language
        )

        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
