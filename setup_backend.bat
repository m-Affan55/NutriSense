@echo off
echo ===================================================
echo Setting up FastAPI Backend Virtual Environment...
echo ===================================================
cd /d "%~dp0backend"

if not exist venv (
    echo Creating virtual environment...
    python -m venv venv
)

echo Activating virtual environment...
call venv\Scripts\activate

echo Upgrading pip...
python -m pip install --upgrade pip

echo Installing dependencies from requirements.txt...
pip install -r requirements.txt

echo ===================================================
echo Backend setup complete!
echo ===================================================
pause
