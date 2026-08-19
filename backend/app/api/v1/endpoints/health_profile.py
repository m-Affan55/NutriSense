from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
from app.db.supabase_client import get_supabase_admin_client

router = APIRouter()

class OnboardingData(BaseModel):
    user_id: str
    age: int
    gender: str
    weight_kg: float
    height_cm: float
    goal: str
    activity_level: str
    medical_conditions: List[str]
    dietary_restrictions: List[str]
    daily_budget_pkr: int

@router.post("/onboarding")
def create_health_profile(data: OnboardingData):
    try:
        # Calculate TDEE using Mifflin-St Jeor equation
        if data.gender.lower() == 'male':
            bmr = (10 * data.weight_kg) + (6.25 * data.height_cm) - (5 * data.age) + 5
        else:
            bmr = (10 * data.weight_kg) + (6.25 * data.height_cm) - (5 * data.age) - 161

        activity_multipliers = {
            'sedentary': 1.2,
            'lightly_active': 1.375,
            'moderately_active': 1.55,
            'very_active': 1.725
        }
        
        # Default to sedentary if unknown
        multiplier = activity_multipliers.get(data.activity_level.lower(), 1.2)
        tdee = bmr * multiplier

        # Adjust calories based on goal
        if data.goal.lower() == 'fat_loss':
            daily_calories = tdee - 500
        elif data.goal.lower() == 'muscle_gain':
            daily_calories = tdee + 300
        else:
            daily_calories = tdee

        # Calculate Macros
        # Protein: 2g per kg of bodyweight
        daily_protein_g = int(data.weight_kg * 2)
        
        # Fat: 25% of total calories (9 calories per gram of fat)
        daily_fat_g = int((daily_calories * 0.25) / 9)
        
        # Carbs: Remaining calories (4 calories per gram of carb)
        calories_from_protein = daily_protein_g * 4
        calories_from_fat = daily_fat_g * 9
        remaining_calories = daily_calories - calories_from_protein - calories_from_fat
        daily_carbs_g = int(remaining_calories / 4)

        # Prepare DB payload
        db_payload = {
            "user_id": data.user_id,
            "age": data.age,
            "gender": data.gender.lower(),
            "weight_kg": data.weight_kg,
            "height_cm": data.height_cm,
            "goal": data.goal,
            "activity_level": data.activity_level,
            "medical_conditions": data.medical_conditions,
            "dietary_restrictions": data.dietary_restrictions,
            "daily_budget_pkr": data.daily_budget_pkr,
            "daily_calorie_target": int(daily_calories),
            "daily_protein_g": daily_protein_g,
            "daily_carbs_g": daily_carbs_g,
            "daily_fat_g": daily_fat_g,
        }

        # Insert into Supabase using Admin client
        supabase = get_supabase_admin_client()
        response = supabase.table('health_profiles').insert(db_payload).execute()

        return {
            "message": "Health profile created successfully",
            "daily_calorie_target": int(daily_calories),
            "daily_protein_g": daily_protein_g,
            "daily_carbs_g": daily_carbs_g,
            "daily_fat_g": daily_fat_g,
            "data": response.data
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
