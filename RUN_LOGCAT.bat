@echo off
REM === Image Reading Diagnostic Script ===
REM Run this script to see detailed logs while reading a card

setlocal enabledelayedexpansion

echo.
echo ========== STEP 1: Check Device Connection ==========
adb devices
echo.
pause

echo.
echo ========== STEP 2: Clear Old Logs ==========
adb logcat -c
echo Logs cleared. Ready to capture new logs.
echo.
pause

echo.
echo ========== STEP 3: Capture Logs (Live Monitor) ==========
echo When you're ready:
echo 1. Click READ CARD in the app
echo 2. Wait for the card to be read
echo 3. Press Ctrl+C to stop logging
echo.
echo Looking for these SUCCESS messages:
echo   - "Calling decodeFaceImage"
echo   - "writeFaceToFile"
echo   - "SUCCESS"
echo.
adb logcat -s TAKA_USB:V

echo.
echo ========== Logging Complete ==========
echo.
pause
