import os
import sys
from dotenv import load_dotenv
from pydantic import ValidationError

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"))

from app.api.v1.endpoints.health_profile import OnboardingData
from app.api.v1.endpoints.coach import CoachRequest, ChatMessage
from app.api.v1.endpoints.meals import BarcodeRequest, SearchFoodRequest

def test_category2_input_validations():
    print("==================================================")
    print("  RUNNING CATEGORY 2 ADVERSARIAL QA AUDIT TESTS   ")
    print("==================================================")

    # ─────────────────────────────────────────────────────────────
    # ISSUE 5: Onboarding Age, Weight, Height & Macro Validations
    # ─────────────────────────────────────────────────────────────
    print("\n[TEST 1] Testing Issue 5: Onboarding Data Validations...")

    # 1.1 Age < 6 must fail
    invalid_ages = [0, -1, -25, 4, 5, 125]
    for bad_age in invalid_ages:
        try:
            OnboardingData(
                user_id="test_user",
                age=bad_age,
                gender="male",
                weight_kg=70.0,
                height_cm=175.0,
                goal="fat_loss",
                activity_level="sedentary",
                medical_conditions=[],
                dietary_restrictions=[],
                daily_budget_pkr=1000
            )
            assert False, f"Failed to reject invalid age: {bad_age}"
        except ValidationError:
            print(f"  [OK] Successfully rejected invalid age: {bad_age}")

    # 1.2 Weight <= 0 or < 15 must fail
    invalid_weights = [0.0, -5.0, 10.0, 450.0]
    for bad_weight in invalid_weights:
        try:
            OnboardingData(
                user_id="test_user",
                age=25,
                gender="male",
                weight_kg=bad_weight,
                height_cm=175.0,
                goal="fat_loss",
                activity_level="sedentary",
                medical_conditions=[],
                dietary_restrictions=[],
                daily_budget_pkr=1000
            )
            assert False, f"Failed to reject invalid weight: {bad_weight}"
        except ValidationError:
            print(f"  [OK] Successfully rejected invalid weight: {bad_weight}")

    # 1.3 Height <= 0 or < 50 or > 280 must fail
    invalid_heights = [0.0, -10.0, 35.0, 300.0]
    for bad_height in invalid_heights:
        try:
            OnboardingData(
                user_id="test_user",
                age=25,
                gender="female",
                weight_kg=60.0,
                height_cm=bad_height,
                goal="fat_loss",
                activity_level="sedentary",
                medical_conditions=[],
                dietary_restrictions=[],
                daily_budget_pkr=1000
            )
            assert False, f"Failed to reject invalid height: {bad_height}"
        except ValidationError:
            print(f"  [OK] Successfully rejected invalid height: {bad_height}")

    # 1.4 Valid onboarding data must pass
    valid_onboarding = OnboardingData(
        user_id="valid_user_123",
        age=6,  # Min age 6 accepted
        gender="male",
        weight_kg=20.0,
        height_cm=115.0,
        goal="maintenance",
        activity_level="lightly_active",
        medical_conditions=["None"],
        dietary_restrictions=[],
        daily_budget_pkr=1500
    )
    assert valid_onboarding.age == 6
    assert valid_onboarding.weight_kg == 20.0
    print("  [OK] Successfully validated valid onboarding record with minimum age=6")

    # ─────────────────────────────────────────────────────────────
    # ISSUE 6: AI Coach Message Length & History Flood Defense
    # ─────────────────────────────────────────────────────────────
    print("\n[TEST 2] Testing Issue 6: Coach Request Length Limits...")

    # 2.1 Oversized message (>3000 chars) must fail
    oversized_text = "A" * 3500
    try:
        CoachRequest(
            user_id="user_123",
            message=oversized_text,
            history=[]
        )
        assert False, "Failed to reject oversized message"
    except ValidationError:
        print("  [OK] Successfully rejected 3500-char message (Max length enforced)")

    # 2.2 Empty message must fail
    try:
        CoachRequest(
            user_id="user_123",
            message="",
            history=[]
        )
        assert False, "Failed to reject empty message"
    except ValidationError:
        print("  [OK] Successfully rejected empty message")

    # 2.3 Valid CoachRequest with ChatMessage history must pass
    valid_coach_req = CoachRequest(
        user_id="user_123",
        message="What is a good high-protein breakfast for Sehri?",
        history=[
            ChatMessage(role="user", content="Hello coach"),
            ChatMessage(role="model", content="Hello! How can I help you today?")
        ]
    )
    assert len(valid_coach_req.history) == 2
    print("  [OK] Successfully validated structured CoachRequest with ChatMessage history")

    # ─────────────────────────────────────────────────────────────
    # ISSUE 7: Barcode String Injection & Format Defense
    # ─────────────────────────────────────────────────────────────
    print("\n[TEST 3] Testing Issue 7: Barcode Format & Injection Defense...")

    # 3.1 Non-numeric / injection strings must fail
    malicious_barcodes = [
        "><script>alert(1)</script>",
        "SELECT * FROM products;",
        "EAN_BARCODE_ABC",
        "123",        # Too short (< 4 digits)
        "123456789012345678901"  # Too long (> 18 digits)
    ]
    for bad_barcode in malicious_barcodes:
        try:
            BarcodeRequest(
                barcode=bad_barcode,
                user_id="user_123"
            )
            assert False, f"Failed to reject invalid/malicious barcode: {bad_barcode}"
        except ValidationError:
            print(f"  [OK] Successfully rejected invalid barcode: {bad_barcode}")

    # 3.2 Valid standard numeric barcodes must pass
    valid_barcodes = ["3017620422003", "8964000123456", "7622210449283", "12345678"]
    for good_barcode in valid_barcodes:
        req = BarcodeRequest(barcode=good_barcode, user_id="user_123")
        assert req.barcode == good_barcode
        print(f"  [OK] Successfully validated numeric barcode: {good_barcode}")

    # 3.3 SearchFoodRequest length constraints
    try:
        SearchFoodRequest(query="X" * 500)
        assert False, "Failed to reject oversized search food query"
    except ValidationError:
        print("  [OK] Successfully rejected 500-char food search query")

    print("\n==================================================")
    print("  ALL CATEGORY 2 VERIFICATION TESTS PASSED!       ")
    print("==================================================")

if __name__ == "__main__":
    test_category2_input_validations()
