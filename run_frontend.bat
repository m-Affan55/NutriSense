@echo off
echo ===================================================
echo Starting Flutter Frontend App...
echo ===================================================
cd /d "%~dp0frontend"

echo Fetching dependencies...
call flutter pub get

echo Setting up ADB reverse for physical device (port 8000)...
set ADB="%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
%ADB% reverse tcp:8000 tcp:8000
if %errorlevel% neq 0 (
    echo [WARNING] adb reverse failed. Is your phone connected with USB Debugging on?
    echo [WARNING] The app will still run but may not connect to the backend.
)

echo Starting Flutter App...
call flutter run

pause
