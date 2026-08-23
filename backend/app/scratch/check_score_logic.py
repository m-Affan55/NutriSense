import os
from dotenv import load_dotenv

# Load env
load_dotenv(r'd:\mobileAppDev\BanoQabilHackathon\NutriSense\backend\.env')

from supabase import create_client, Client

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
if not key:
    key = os.environ.get("SUPABASE_KEY")

supabase: Client = create_client(url, key)

def test_score():
    user_id = '23f83316-5975-49ff-8bc6-bb8b37821892'
    
    # 2. get profile
    profile_res = supabase.table('health_profiles').select('*').eq('user_id', user_id).maybe_single().execute()
    profile = profile_res.data if hasattr(profile_res, 'data') else profile_res
    if not profile:
        print("No health profile found.")
        return
        
    target_cal = profile.get('daily_calorie_target', 2000)
    target_pro = profile.get('daily_protein_g', 50)
    print(f"Targets - Calories: {target_cal}, Protein: {target_pro}")

    # 3. get meals for today
    import datetime
    now_utc = datetime.datetime.now(datetime.timezone.utc)
    today_start = now_utc.replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    meals_res = supabase.table('meal_logs').select('*').eq('user_id', user_id).gte('logged_at', today_start).execute()
    
    meals = meals_res.data
    
    day_cal = 0
    day_pro = 0
    
    print("\n--- Meals Logged Today ---")
    for m in meals:
        print(f"Date: {m.get('logged_at')}, Meal: {m.get('notes')}, Cals: {m.get('total_calories')}, Pro: {m.get('total_protein_g')}")
        day_cal += (m.get('total_calories') or 0)
        day_pro += (m.get('total_protein_g') or 0)

    print(f"\nTotal Today - Calories: {day_cal}, Protein: {day_pro}")
    
    cal_diff = abs(day_cal - target_cal) / max(target_cal, 1)
    pro_ratio = day_pro / max(target_pro, 1)
    
    print(f"Calorie diff: {cal_diff:.2f} (Needs to be <= 0.20 to get points)")
    print(f"Protein ratio: {pro_ratio:.2f} (Needs to be >= 0.80 to get points)")
    
    if cal_diff <= 0.2:
        print("-> Calorie goal MET for today!")
    else:
        print("-> Calorie goal NOT met yet. Habit score for today's calories is 0.")
        
    if pro_ratio >= 0.8:
        print("-> Protein goal MET for today!")
    else:
        print("-> Protein goal NOT met yet. Habit score for today's protein is 0.")

if __name__ == '__main__':
    test_score()
