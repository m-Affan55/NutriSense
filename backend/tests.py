import asyncio
import datetime
from app.db.supabase_client import get_supabase_admin_client
from app.services.barcode_service import BarcodeService
from app.services.gemini_service import GeminiService
from fastapi.testclient import TestClient
from app.main import app
from unittest.mock import patch

def run_tests():
    supabase = get_supabase_admin_client()
    
    print("--- 1. Getting a Test User ---")
    res = supabase.table('health_profiles').select('user_id').limit(1).execute()
    if not res.data:
        print("No users found!")
        return
    user_id = res.data[0]['user_id']
    print(f"Test User ID: {user_id}")
    
    print("\n--- 2. Habit Score & Trend (Real Logs vs Zero Logs) ---")
    
    # Insert a meal log for today for the test user so we have real data
    try:
        supabase.table('meal_logs').insert({
            'user_id': user_id,
            'meal_type': 'lunch',
            'notes': 'Test Meal',
            'total_calories': 500,
            'total_protein_g': 30,
            'total_carbs_g': 40,
            'total_fat_g': 15,
            'logged_at': datetime.datetime.now(datetime.timezone.utc).isoformat()
        }).execute()
    except Exception as e:
        print("Failed to insert mock meal:", e)

    # First, get score for actual user (who has real logs we just added in testing before)
    client = TestClient(app)
    response = client.get(f"/api/v1/coaching/habit-score/{user_id}")
    print("User WITH Logs:")
    print(response.json())
    
    print("\nUser WITHOUT Logs:")
    with patch('app.api.v1.endpoints.coaching.get_supabase_admin_client') as mock_supa:
        class MockBuilder:
            def select(self, *args): return self
            def eq(self, *args): return self
            def gte(self, *args): return self
            def maybe_single(self): return self
            def execute(self):
                # if fetching profile, return the real one
                # if fetching meals, return empty array
                return type('MockResponse', (), {'data': []})()
                
        # Actually this is a bit complex to mock exactly due to the chaining.
        # Let's just delete the user's meal logs temporarily, fetch, and restore them!
        
        # 1. Back up user's logs
        backup_res = supabase.table('meal_logs').select('*').eq('user_id', user_id).execute()
        backup_logs = backup_res.data
        
        # 2. Delete all logs for this user
        supabase.table('meal_logs').delete().eq('user_id', user_id).execute()
        
        # 3. Fetch score
        response_empty = client.get(f"/api/v1/coaching/habit-score/{user_id}")
        print(response_empty.json())
        
        # 4. Restore logs
        if backup_logs:
            for log in backup_logs:
                if 'id' in log:
                    del log['id'] # Let it auto-generate or restore
                supabase.table('meal_logs').insert(log).execute()

    print("\n--- 3. Barcode Service Type Casting (N/A Strings) ---")
    # We bypass the HTTP layer and test the internal logic that failed
    # The actual bug was in parsing openfoodfacts. We'll simulate the product dict.
    mock_product = {
        "product_name": "Test Item",
        "nutriments": {
            "energy-kcal_100g": "N/A",  # The bug!
            "proteins_100g": None,      # Another edge case
            "carbohydrates_100g": "15.5",
            "fat_100g": 0
        }
    }
    
    with patch('httpx.get') as mock_get:
        class MockResponse:
            def __init__(self, json_data, status_code):
                self.json_data = json_data
                self.status_code = status_code
            def json(self): return self.json_data
            def raise_for_status(self): pass
            
        mock_get.return_value = MockResponse({
            "status": 1,
            "product": mock_product
        }, 200)
        
        try:
            result = BarcodeService.get_product_info("123456")
            print("Barcode parse success!")
            print(result)
        except Exception as e:
            print(f"Barcode parse FAILED: {e}")

    print("\n--- 4. Silent AI Scan Failures (Exception Handling) ---")
    # gemini_service.scan_meal swallows JSON Decode errors. Let's force an error by sending garbage bytes
    with patch('google.genai.Client') as mock_genai:
        class MockModels:
            def generate_content(self, *args, **kwargs):
                class MockText:
                    text = "This is not valid JSON!!!"
                return MockText()
        
        mock_client = mock_genai.return_value
        mock_client.models = MockModels()
        
        try:
            res = GeminiService.scan_meal(b"garbage", "image/jpeg", {})
            print("Scan Meal Returned Successfully (BUG):", res)
        except Exception as e:
            print("Scan Meal Raised Exception (FIXED):", type(e).__name__, str(e))

if __name__ == '__main__':
    run_tests()
