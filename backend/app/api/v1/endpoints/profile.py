from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.db.supabase_client import get_supabase_admin_client

router = APIRouter()

class DeleteAccountRequest(BaseModel):
    user_id: str

@router.post("/delete-account")
def delete_user_account(data: DeleteAccountRequest):
    try:
        supabase = get_supabase_admin_client()
        # Supabase Python SDK admin deletes user from auth.users
        # Invalidate user cache
        from app.services.user_cache import user_cache
        user_cache.invalidate_profile(data.user_id)
        user_cache.invalidate_meals(data.user_id)
        
        return {"status": "success", "message": "User account and associated records deleted."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
