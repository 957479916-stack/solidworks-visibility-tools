@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1"
if errorlevel 1 (
  echo.
  echo Uninstall failed. See the error message above.
  pause
  exit /b 1
)
echo.
echo Uninstall completed. Press any key to close.
pause
