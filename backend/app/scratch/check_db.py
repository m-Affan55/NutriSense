import os
import sys
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..'))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))

from app.db.supabase_client import get_supabase_admin_client

def main():
    supabase = get_supabase_admin_client()
    
    # Fetch latest profiles
    profiles = supabase.table('health_profiles').select('*').execute().data
    print("PROFILES:")
    for p in profiles:
        print(f"User: {p.get('user_id')}, Name: {p.get('full_name')}")
        
    if not profiles:
        print("No profiles found")
        return
        
    user_id = profiles[0]['user_id']
    
    # Fetch meals
    meals = supabase.table('meal_logs').select('*').eq('user_id', user_id).execute().data
    print("\nMEALS:")
    for m in meals:
        print(f"Logged At: {m.get('logged_at')}, Notes: {m.get('notes')}, Cals: {m.get('total_calories')}")
        
    # Fetch water
    water = supabase.table('water_logs').select('*').eq('user_id', user_id).execute().data
    print("\nWATER:")
    for w in water:
        print(f"Logged At: {w.get('logged_at')}, Amount: {w.get('amount_ml')}")

if __name__ == '__main__':
    main()
