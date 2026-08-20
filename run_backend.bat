@echo off
echo ===================================================
echo Starting FastAPI Backend Server...
echo ===================================================
cd /d "%~dp0backend"

if exist venv\Scripts\activate.bat (
    echo Activating virtual environment...
    call venv\Scripts\activate
) else (
    echo [WARNING] No virtual environment found. Running globally...
)

echo Starting uvicorn app.main:app on port 8000...
uvicorn app.main:app --reload

pause
