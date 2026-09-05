import sys
import os

# Add backend directory to path
backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, backend_dir)

from app.services.gemini_service import GeminiService

def test_screenshot_case_diabetes_low_goal():
    print("--- Test 1: User's Exact Screenshot (65 steps, 500 goal, Diabetes profile, 0 sleep, 0 HR) ---")
    activity = {
        "steps": 65,
        "step_goal": 500,
        "active_kcal": 3,
        "sleep_hours": 0.0,
        "heart_rate": 0,
        "source": "Health Connect"
    }
    profile = {
        "goal": "Manage Blood Sugar",
        "medical_conditions": ["Type 2 Diabetes"],
        "dietary_restrictions": ["Low Sugar"],
        "age": 45,
        "gender": "Male",
        "weight_kg": 78
    }
    
    result = GeminiService.generate_health_sync_insight(activity, profile, language="en")
    print("Result:", result)
    assert result["is_goal_adequate"] == False, f"Expected is_goal_adequate=False, got {result['is_goal_adequate']}"
    assert result["optimal_step_goal"] >= 6000, f"Expected optimal_step_goal>=6000, got {result['optimal_step_goal']}"
    
    # Check Hardware Shield: sleep and heart rate should NOT be mentioned
    insight_lower = result["insight"].lower()
    feedback_lower = result["goal_feedback"].lower()
    combined = insight_lower + " " + feedback_lower
    assert "0 hours of sleep" not in combined, "Hardware shield failed: mentioned 0 hours sleep"
    assert "did not sleep" not in combined, "Hardware shield failed: claimed user did not sleep"
    assert "missing heart rate" not in combined, "Hardware shield failed: mentioned missing heart rate"
    print("PASSED Test 1!")

def test_fat_loss_adequate_goal():
    print("\n--- Test 2: Fat Loss with Adequate Goal (8,500 steps, 8,000 goal) ---")
    activity = {
        "steps": 8500,
        "step_goal": 8000,
        "active_kcal": 380,
        "sleep_hours": 0.0,
        "heart_rate": 0,
        "source": "User Logged"
    }
    profile = {
        "goal": "Weight Loss",
        "medical_conditions": [],
        "dietary_restrictions": [],
        "age": 28,
        "gender": "Female",
        "weight_kg": 68
    }
    result = GeminiService.generate_health_sync_insight(activity, profile, language="en")
    print("Result:", result)
    assert result["is_goal_adequate"] == True, f"Expected is_goal_adequate=True, got {result['is_goal_adequate']}"
    assert result["optimal_step_goal"] >= 7000, f"Expected optimal_step_goal>=7000, got {result['optimal_step_goal']}"
    print("PASSED Test 2!")

def test_urdu_localization():
    print("\n--- Test 3: Urdu Localization (Hypertension profile, low goal) ---")
    activity = {
        "steps": 1200,
        "step_goal": 2000,
        "active_kcal": 55,
        "sleep_hours": 0.0,
        "heart_rate": 0,
        "source": "Health Connect"
    }
    profile = {
        "goal": "Lower Blood Pressure",
        "medical_conditions": ["Hypertension"],
        "dietary_restrictions": ["Low Sodium"],
    }
    result = GeminiService.generate_health_sync_insight(activity, profile, language="ur")
    print("Result keys:", list(result.keys()))
    print("Optimal goal:", result["optimal_step_goal"])
    print("Is adequate:", result["is_goal_adequate"])
    assert result["is_goal_adequate"] == False, f"Expected is_goal_adequate=False, got {result['is_goal_adequate']}"
    assert len(result["insight"]) > 0, "Expected non-empty insight"
    print("PASSED Test 3!")

if __name__ == "__main__":
    test_screenshot_case_diabetes_low_goal()
    test_fat_loss_adequate_goal()
    test_urdu_localization()
    print("\nALL BACKEND HEALTH SYNC AI TESTS PASSED SUCCESSFULLY!")
