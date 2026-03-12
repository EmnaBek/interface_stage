@echo off
REM === Test Script for Image Reading Debug ===
REM This script captures detailed logs while you read a card

echo.
echo === Clearing old logs ===
adb logcat -c

echo.
echo === Starting real-time log capture ===
echo >>> When ready, tap READ CARD in the app, then press Ctrl+C to stop logging
echo.
echo Watch for these key messages:
echo   * "Total face bytes received: X" (should be > 0)
echo   * "decodeFaceImage" messages
echo   * "BDB" and "JPEG" messages
echo   * "writeFaceToFile SUCCESS"
echo.

adb logcat -s TAKA_USB:V

echo.
echo === Log capture complete ===
pause
