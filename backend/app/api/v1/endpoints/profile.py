from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from app.db.supabase_client import get_supabase_admin_client
from app.core.security import get_current_user_id

router = APIRouter()

class DeleteAccountRequest(BaseModel):
    user_id: str

@router.post("/delete-account")
def delete_user_account(data: DeleteAccountRequest, authenticated_user_id: str = Depends(get_current_user_id)):
    if data.user_id != authenticated_user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You do not own this resource")
        
    try:
        supabase = get_supabase_admin_client()
        user_id = data.user_id
        
        # Delete rows from all database tables associated with this user
        supabase.table('risk_flags').delete().eq('user_id', user_id).execute()
        supabase.table('meal_logs').delete().eq('user_id', user_id).execute()
        supabase.table('water_logs').delete().eq('user_id', user_id).execute()
        supabase.table('health_profiles').delete().eq('user_id', user_id).execute()
        
        try:
            supabase.table('profiles').delete().eq('id', user_id).execute()
        except Exception:
            pass  # profiles table might be managed natively or optional
            
        # Supabase Python SDK admin deletes user from auth.users
        supabase.auth.admin.delete_user(user_id)
        
        # Invalidate user cache
        from app.services.user_cache import user_cache
        user_cache.invalidate_profile(user_id)
        user_cache.invalidate_meals(user_id)
        
        return {"status": "success", "message": "User account and associated records deleted."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
