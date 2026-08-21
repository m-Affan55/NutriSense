import sys
import os

backend_dir = r"d:\mobileAppDev\BanoQabilHackathon\NutriSense\backend"
sys.path.insert(0, backend_dir)
os.chdir(backend_dir)

from app.api.v1.endpoints.coach import chat_with_coach, CoachRequest

req = CoachRequest(
    user_id="23f83316-5975-49ff-8bc6-bb8b37821892",
    message="i have eaten 5 chocolates and i am not feeling well",
    history=[]
)

try:
    # Need to mock the Supabase client or make sure we have the real environment
    res = chat_with_coach(req)
    print("Success:", res)
except Exception as e:
    import traceback
    traceback.print_exc()
