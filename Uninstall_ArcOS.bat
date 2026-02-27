@echo off
title ArcOS Uninstaller

echo.
echo =============================
echo        ArcOS Uninstaller
echo =============================
echo.

:: --- Check for Administrator ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit
)

cd /d "%~dp0"

echo Running ArcOS state-aware removal...
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0uninstall.ps1"

echo.
echo =============================
echo   ArcOS Uninstalled
echo =============================
echo.

pause