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
    family_member_id: Optional[str] = None,
    is_ramadan: bool = False,
    language: str = "en",
    authenticated_user_id: str = Depends(get_current_user_id)
):
    """
    Returns a personalized 7-day workout plan based on the user's or family member's clinical health profile.
    """
    if user_id != authenticated_user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You do not own this resource")

    profile = None
    if family_member_id:
        try:
            supabase = get_supabase_admin_client()
            fam_res = await run_in_threadpool(
                lambda: supabase.table('family_members').select('*').eq('id', family_member_id).maybe_single().execute()
            )
            fam = fam_res.data if hasattr(fam_res, 'data') else fam_res
            if fam:
                profile = {
                    "name": fam.get("name", "Family Member"),
                    "age": fam.get("age", 30),
                    "gender": fam.get("gender", "male"),
                    "weight_kg": float(fam.get("weight_kg") or 65.0),
                    "height_cm": float(fam.get("height_cm") or 165.0),
                    "goal": fam.get("goal") or "General Health & Mobility",
                    "activity_level": fam.get("activity_level") or "moderately_active",
                    "medical_conditions": fam.get("medical_conditions", [])
                }
        except Exception as e:
            print(f"[WorkoutAPI] Failed to fetch family member from DB: {e}")

    # 1. Fetch user health profile if not for a family member
    if not profile:
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
        is_ramadan=is_ramadan,
        language=language
    )

    return plan


@router.post("/generate", response_model=WorkoutPlanResponse)
async def regenerate_workout_plan(
    req: WorkoutPlanRequest,
    authenticated_user_id: str = Depends(get_current_user_id)
):
    """
    Generates or refreshes a personalized workout plan using user profile or family member data.
    """
    if req.user_id != authenticated_user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You do not own this resource")

    profile = None
    if req.family_member_id:
        try:
            supabase = get_supabase_admin_client()
            fam_res = await run_in_threadpool(
                lambda: supabase.table('family_members').select('*').eq('id', req.family_member_id).maybe_single().execute()
            )
            fam = fam_res.data if hasattr(fam_res, 'data') else fam_res
            if fam:
                profile = {
                    "name": fam.get("name", "Family Member"),
                    "age": fam.get("age", 30),
                    "gender": fam.get("gender", "male"),
                    "weight_kg": float(fam.get("weight_kg") or 65.0),
                    "height_cm": float(fam.get("height_cm") or 165.0),
                    "goal": fam.get("goal") or "General Health & Mobility",
                    "activity_level": fam.get("activity_level") or "moderately_active",
                    "medical_conditions": fam.get("medical_conditions", [])
                }
        except Exception as e:
            print(f"[WorkoutAPI] Failed to fetch family member from DB: {e}")

    if not profile:
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
        is_ramadan=req.is_ramadan or False,
        language=req.language or "en"
    )

    return plan
