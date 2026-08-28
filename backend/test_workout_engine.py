import os
import sys
from fastapi.testclient import TestClient
from app.main import app
from app.core.security import get_current_user_id
from app.services.workout_service import WorkoutService

def run_workout_tests():
    print("==================================================")
    print("  RUNNING CLINICAL WORKOUT ENGINE & API TESTS     ")
    print("==================================================")

    # 1. Test Diabetic + Fat Loss Plan Generation
    print("\n[TEST 1] Testing Diabetic + Fat Loss Plan...")
    diabetic_profile = {
        "age": 42,
        "gender": "male",
        "weight_kg": 88.0,
        "height_cm": 172.0,
        "goal": "fat_loss",
        "activity_level": "sedentary",
        "medical_conditions": ["Diabetes / High Blood Sugar"]
    }
    plan1 = WorkoutService.generate_workout_plan(diabetic_profile)
    assert "weekly_schedule" in plan1, "Plan 1 missing weekly_schedule"
    assert len(plan1["weekly_schedule"]) == 7, "Weekly schedule must have 7 days"
    print("  [OK] Successfully generated Diabetic Fat-Loss plan:", plan1["plan_name"])
    print("  [OK] Weekly frequency:", plan1["weekly_frequency"])
    print("  [OK] Sample medical note:", plan1["medical_considerations"][:1])

    # 2. Test Hypertension + Muscle Gain Plan
    print("\n[TEST 2] Testing Hypertension + Muscle Gain Plan...")
    hypertensive_profile = {
        "age": 35,
        "gender": "male",
        "weight_kg": 68.0,
        "height_cm": 180.0,
        "goal": "muscle_gain",
        "activity_level": "lightly_active",
        "medical_conditions": ["Hypertension / High Blood Pressure"]
    }
    plan2 = WorkoutService.generate_workout_plan(hypertensive_profile)
    assert len(plan2["weekly_schedule"]) == 7
    print("  [OK] Successfully generated Hypertensive Muscle Gain plan:", plan2["plan_name"])

    # 3. Test Joint Pain / Knee Issues Plan
    print("\n[TEST 3] Testing Joint Pain / Arthritis Plan...")
    joint_profile = {
        "age": 55,
        "gender": "female",
        "weight_kg": 75.0,
        "height_cm": 160.0,
        "goal": "maintain",
        "activity_level": "sedentary",
        "medical_conditions": ["Joint Pain / Arthritis"]
    }
    plan3 = WorkoutService.generate_workout_plan(joint_profile)
    assert len(plan3["weekly_schedule"]) == 7
    print("  [OK] Successfully generated Joint-Safe plan:", plan3["plan_name"])

    # 4. Test Deterministic Fallback Engine
    print("\n[TEST 4] Testing Deterministic Clinical Fallback...")
    fallback_plan = WorkoutService._generate_clinical_fallback(diabetic_profile)
    assert len(fallback_plan["weekly_schedule"]) == 7
    assert fallback_plan["weekly_schedule"][2]["is_rest_day"] is True  # Wednesday is rest day
    print("  [OK] Fallback plan generated with 7 days and verified rest days")

    # 5. Test FastAPI HTTP Endpoints
    print("\n[TEST 5] Testing FastAPI Workout Router Endpoints...")
    app.dependency_overrides[get_current_user_id] = lambda: "test_workout_user"
    client = TestClient(app)

    response = client.get("/api/v1/workout/plan/test_workout_user")
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert "weekly_schedule" in data
    assert len(data["weekly_schedule"]) == 7
    print("  [OK] GET /api/v1/workout/plan/{user_id} returned 200 OK with full 7-day schedule")

    regen_res = client.post("/api/v1/workout/generate", json={
        "user_id": "test_workout_user",
        "client_profile": hypertensive_profile,
        "is_ramadan": False
    })
    assert regen_res.status_code == 200
    print("  [OK] POST /api/v1/workout/generate returned 200 OK")

    print("\n==================================================")
    print("  ALL WORKOUT BACKEND TESTS PASSED (100% SUCCESS) ")
    print("==================================================")

if __name__ == '__main__':
    run_workout_tests()
