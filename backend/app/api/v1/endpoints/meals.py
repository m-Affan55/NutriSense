from fastapi import APIRouter, File, UploadFile, Form, HTTPException
from app.services.gemini_service import GeminiService
from app.db.supabase_client import get_supabase_admin_client

router = APIRouter()

@router.post("/scan")
async def scan_meal(
    image: UploadFile = File(...),
    user_id: str = Form(...)
):
    try:
        # 1. Fetch user's health profile to get conditions and allergies context
        supabase = get_supabase_admin_client()
        profile_response = supabase.table('health_profiles').select('*').eq('user_id', user_id).maybe_single().execute()
        profile = profile_response.data
        
        # 2. Read image details
        image_bytes = await image.read()
        mime_type = image.content_type or "image/jpeg"
        
        # 3. Analyze plate using Gemini interactions service
        scan_result = GeminiService.scan_meal(
            image_bytes=image_bytes,
            mime_type=mime_type,
            profile=profile
        )
        
        return scan_result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
