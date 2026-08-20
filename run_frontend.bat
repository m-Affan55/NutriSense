@echo off
echo ===================================================
echo Starting Flutter Frontend App...
echo ===================================================
cd /d "%~dp0frontend"

echo Fetching dependencies...
call flutter pub get

echo Starting Flutter App...
call flutter run

pause
