from fastapi import APIRouter, HTTPException, Query, Response
from app.services.report_service import ReportService

router = APIRouter()

@router.get("/weekly")
def get_weekly_report(
    user_id: str = Query(..., description="Unique user identifier"),
    language: str = Query("en", description="Target language ('en' or 'ur')")
):
    """
    Generates a personalized AI weekly nutritional and adherence report.
    """
    try:
        report = ReportService.generate_weekly_report(user_id=user_id, language=language)
        return report
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate weekly report: {str(e)}")


@router.get("/weekly/pdf")
def export_weekly_pdf_report(
    user_id: str = Query(..., description="Unique user identifier"),
    language: str = Query("en", description="Target language ('en' or 'ur')")
):
    """
    Generates and downloads a clinical PDF report containing 7-day adherence metrics and AI review.
    """
    try:
        pdf_bytes = ReportService.generate_pdf_report(user_id=user_id, language=language)
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
