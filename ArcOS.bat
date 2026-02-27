@echo off
title ArcOS Deployment

:: Require admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

echo.
echo Starting ArcOS...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0main.ps1"
set exitcode=%errorlevel%

echo.

if %exitcode% neq 0 (
    echo ArcOS failed with exit code %exitcode%.
    pause
    exit /b %exitcode%
)

echo ArcOS completed successfully.
pause