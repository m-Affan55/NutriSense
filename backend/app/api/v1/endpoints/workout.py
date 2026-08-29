from fastapi import APIRouter, HTTPException, Depends
from fastapi.concurrency import run_in_threadpool
from typing import Optional
from app.db.supabase_client import get_supabase_admin_client
from app.services.user_cache import user_cache
from app.services.workout_service import WorkoutService
from app.schemas.workout import WorkoutPlanResponse, WorkoutPlanRequest
from app.core.security import get_current_user_id

router = APIRouter()

@router.get("/plan/{user_id}", response_model=WorkoutPlanResponse)
async def get_workout_plan(
    user_id: str,
    is_ramadan: bool = False,
    authenticated_user_id: str = Depends(get_current_user_id)
):
    """
    Returns a personalized 7-day workout plan based on the user's clinical health profile,
    biometrics, and medical conditions.
    """
    if user_id != authenticated_user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You do not own this resource")

    # 1. Fetch user health profile
    profile = user_cache.get_profile(user_id)
    if not profile:
        try:
            supabase = get_supabase_admin_client()
            res = await run_in_threadpool(
                lambda: supabase.table('health_profiles').select('*').eq('user_id', user_id).maybe_single().execute()
            )
            if res and res.data:
                profile = res.data
                user_cache.set_profile(user_id, profile)
        except Exception as e:
            print(f"[WorkoutAPI] Failed to fetch profile from DB: {e}")

    # Fallback to standard defaults if profile doesn't exist yet
    if not profile:
        profile = {
            "age": 25,
            "gender": "male",
            "weight_kg": 70.0,
            "height_cm": 175.0,
            "goal": "maintain",
            "activity_level": "sedentary",
            "medical_conditions": []
        }

    # 2. Generate workout plan non-blocking
    plan = await run_in_threadpool(
        WorkoutService.generate_workout_plan,
        profile=profile,
        is_ramadan=is_ramadan
    )

    return plan


@router.post("/generate", response_model=WorkoutPlanResponse)
async def regenerate_workout_plan(
    req: WorkoutPlanRequest,
    authenticated_user_id: str = Depends(get_current_user_id)
):
    """
    Generates or refreshes a personalized workout plan using user profile data.
    """
    if req.user_id != authenticated_user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You do not own this resource")

    profile = req.client_profile or user_cache.get_profile(req.user_id)
    if not profile:
        try:
            supabase = get_supabase_admin_client()
            res = await run_in_threadpool(
                lambda: supabase.table('health_profiles').select('*').eq('user_id', req.user_id).maybe_single().execute()
            )
            if res and res.data:
                profile = res.data
                user_cache.set_profile(req.user_id, profile)
        except Exception as e:
            print(f"[WorkoutAPI] DB error: {e}")

    if not profile:
        profile = {
            "age": 25,
            "gender": "male",
            "weight_kg": 70.0,
            "height_cm": 175.0,
            "goal": "maintain",
            "activity_level": "sedentary",
            "medical_conditions": []
        }

    plan = await run_in_threadpool(
        WorkoutService.generate_workout_plan,
        profile=profile,
        is_ramadan=req.is_ramadan or False
    )

    return plan
