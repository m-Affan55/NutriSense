from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import List
from app.db.supabase_client import get_supabase_admin_client
from app.core.security import get_current_user_id

router = APIRouter()

class OnboardingData(BaseModel):
    user_id: str = Field(..., min_length=1, max_length=128)
    age: int = Field(..., ge=6, le=120, description="Age in years (6 to 120)")
    gender: str = Field(..., min_length=1, max_length=20)
    weight_kg: float = Field(..., ge=15.0, le=400.0, description="Weight in kg (15 to 400)")
    height_cm: float = Field(..., ge=50.0, le=280.0, description="Height in cm (50 to 280)")
    goal: str = Field(default="maintenance", max_length=50)
    activity_level: str = Field(default="sedentary", max_length=50)
    medical_conditions: List[str] = Field(default_factory=list)
    dietary_restrictions: List[str] = Field(default_factory=list)
    daily_budget_pkr: int = Field(default=1000, ge=0, le=1_000_000)

@router.post("/onboarding")
def create_health_profile(data: OnboardingData, authenticated_user_id: str = Depends(get_current_user_id)):
    if data.user_id != authenticated_user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You do not own this resource")

    try:
        # Sanitize Gender for Postgres check constraint: ('male', 'female', 'other')
        raw_gender = (data.gender or 'male').lower()
        if raw_gender not in ('male', 'female', 'other'):
            raw_gender = 'other'

        # Sanitize Goal for Postgres check constraint: ('fat_loss', 'muscle_gain', 'maintenance')
        raw_goal = (data.goal or 'maintenance').lower()
        if 'fat' in raw_goal or 'loss' in raw_goal or 'lose' in raw_goal:
            db_goal = 'fat_loss'
        elif 'muscle' in raw_goal or 'gain' in raw_goal or 'bulk' in raw_goal:
            db_goal = 'muscle_gain'
        else:
            db_goal = 'maintenance'

        # Sanitize Activity Level for Postgres check constraint: ('sedentary', 'lightly_active', 'moderately_active', 'very_active')
        raw_act = (data.activity_level or 'sedentary').lower()
        if 'very' in raw_act:
            db_act = 'very_active'
        elif 'mod' in raw_act:
            db_act = 'moderately_active'
        elif 'light' in raw_act:
            db_act = 'lightly_active'
        else:
            db_act = 'sedentary'

        # Preserve clinical context: if user selected diabetes/blood sugar, ensure Diabetes condition is attached
        conditions = list(data.medical_conditions)
        if ('diabetes' in raw_goal or 'blood sugar' in raw_goal) and not any('diabet' in c.lower() for c in conditions):
            conditions.append('Diabetes')

        # Calculate TDEE using Mifflin-St Jeor equation
        if raw_gender == 'male':
            bmr = (10 * data.weight_kg) + (6.25 * data.height_cm) - (5 * data.age) + 5
        else:
            bmr = (10 * data.weight_kg) + (6.25 * data.height_cm) - (5 * data.age) - 161

        activity_multipliers = {
            'sedentary': 1.2,
            'lightly_active': 1.375,
            'moderately_active': 1.55,
            'very_active': 1.725
        }
        
        multiplier = activity_multipliers.get(db_act, 1.2)
        tdee = bmr * multiplier

        # Adjust calories based on goal
        if db_goal == 'fat_loss':
            daily_calories = tdee - 500
        elif db_goal == 'muscle_gain':
            daily_calories = tdee + 300
        else:
            daily_calories = tdee

        # Safety floor for daily calorie target
        daily_calories = max(1000.0, daily_calories)

        # Calculate Macros with minimum clinical floors
        # Protein: 2g per kg of bodyweight (min 25g)
        daily_protein_g = max(25, int(data.weight_kg * 2))
        
        # Fat: 25% of total calories (9 calories per gram of fat) (min 20g)
        daily_fat_g = max(20, int((daily_calories * 0.25) / 9))
        
        # Carbs: Remaining calories (4 calories per gram of carb) (min 30g)
        calories_from_protein = daily_protein_g * 4
        calories_from_fat = daily_fat_g * 9
        remaining_calories = max(120.0, daily_calories - calories_from_protein - calories_from_fat)
        daily_carbs_g = max(30, int(remaining_calories / 4))

        # Prepare DB payload matching Supabase PostgreSQL schema exactly
        db_payload = {
            "user_id": data.user_id,
            "age": data.age,
            "gender": raw_gender,
            "weight_kg": data.weight_kg,
            "height_cm": data.height_cm,
            "goal": db_goal,
            "activity_level": db_act,
            "medical_conditions": conditions,
            "dietary_restrictions": data.dietary_restrictions,
            "daily_budget_pkr": data.daily_budget_pkr,
            "daily_calorie_target": int(daily_calories),
            "daily_protein_g": daily_protein_g,
            "daily_carbs_g": daily_carbs_g,
            "daily_fat_g": daily_fat_g,
        }

        # Upsert into Supabase using Admin client (handles both new and existing profiles idempotently)
        supabase = get_supabase_admin_client()
        response = supabase.table('health_profiles').upsert(db_payload, on_conflict='user_id').execute()

        # Update In-Memory User Cache for zero-latency AI Coach lookups
        from app.services.user_cache import user_cache
        user_cache.set_profile(data.user_id, db_payload)

        return {
            "message": "Health profile saved successfully",
            "daily_calorie_target": int(daily_calories),
            "daily_protein_g": daily_protein_g,
            "daily_carbs_g": daily_carbs_g,
            "daily_fat_g": daily_fat_g,
            "data": response.data
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
