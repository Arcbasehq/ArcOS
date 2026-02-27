@echo off
title ArcOS

echo.
echo ===================================
echo              ArcOS
echo     Optimizing Your Windows PC
echo ===================================
echo.

:: Admin check
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

:: Unblock files safely (single-line, no breaks)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0' -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue" >nul 2>&1

echo.
echo Running ArcOS...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0main.ps1"

if %errorlevel% neq 0 (
    echo.
    echo ArcOS encountered an error.
    pause
    exit /b
)

echo.
echo ===================================
echo        Optimization Complete
echo ===================================
echo.
echo Restarting in 5 seconds...
timeout /t 5 >nul
shutdown /r /t 0