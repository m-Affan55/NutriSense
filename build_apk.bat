@echo off
setlocal
echo =========================================================
echo       NutriSense - Android APK Build Tool
echo =========================================================
echo.
echo Select the build type:
echo [1] Universal Release APK (Recommended: 1 APK compatible with all devices, old ^& new)
echo [2] Split-per-ABI Release APKs (Separate smaller APKs: armeabi-v7a for old phones, arm64-v8a for new)
echo [3] Debug APK (Fast build for development/testing)
echo.

set /p choice="Enter option (1, 2, or 3) [Default: 1]: "
if "%choice%"=="" set choice=1

cd /d "%~dp0frontend"

echo.
echo Fetching latest dependencies...
call flutter pub get

if "%choice%"=="1" (
    echo.
    echo ---------------------------------------------------------
    echo Building Universal Release APK...
    echo ---------------------------------------------------------
    call flutter build apk --release
    echo.
    echo Universal APK generated at:
    echo %~dp0frontend\build\app\outputs\flutter-apk\app-release.apk
) else if "%choice%"=="2" (
    echo.
    echo ---------------------------------------------------------
    echo Building Split-per-ABI Release APKs...
    echo ---------------------------------------------------------
    call flutter build apk --split-per-abi --release
    echo.
    echo APKs generated at:
    echo - Older 32-bit phones: %~dp0frontend\build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk
    echo - Modern 64-bit phones: %~dp0frontend\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
    echo - Emulators/x86_64:   %~dp0frontend\build\app\outputs\flutter-apk\app-x86_64-release.apk
) else if "%choice%"=="3" (
    echo.
    echo ---------------------------------------------------------
    echo Building Debug APK...
    echo ---------------------------------------------------------
    call flutter build apk --debug
    echo.
    echo Debug APK generated at:
    echo %~dp0frontend\build\app\outputs\flutter-apk\app-debug.apk
) else (
    echo Invalid choice. Exiting.
)

echo.
echo =========================================================
echo Build complete!
echo =========================================================
pause
