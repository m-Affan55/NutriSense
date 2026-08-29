from fastapi import APIRouter, HTTPException, Query, Response, Depends
from fastapi.concurrency import run_in_threadpool
from app.services.report_service import ReportService
from app.core.security import get_current_user_id

router = APIRouter()

@router.get("/weekly")
async def get_weekly_report(
    user_id: str = Query(..., description="Unique user identifier"),
    language: str = Query("en", description="Target language ('en' or 'ur')"),
    authenticated_user_id: str = Depends(get_current_user_id)
):
    if user_id != authenticated_user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You do not own this resource")
        
    """
    Generates a personalized AI weekly nutritional and adherence report.
    """
    try:
        report = await run_in_threadpool(ReportService.generate_weekly_report, user_id=user_id, language=language)
        return report
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate weekly report: {str(e)}")


@router.get("/weekly/pdf")
async def export_weekly_pdf_report(
    user_id: str = Query(..., description="Unique user identifier"),
    language: str = Query("en", description="Target language ('en' or 'ur')"),
    authenticated_user_id: str = Depends(get_current_user_id)
):
    if user_id != authenticated_user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You do not own this resource")
        
    """
    Generates and downloads a clinical PDF report containing 7-day adherence metrics and AI review.
    """
    try:
        pdf_bytes = await run_in_threadpool(ReportService.generate_pdf_report, user_id=user_id, language=language)
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'attachment; filename="NutriSense_Weekly_Report_{user_id[:8]}.pdf"',
                "Content-Type": "application/pdf"
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to export PDF report: {str(e)}")
