@echo off
title ArcOS Launcher

:: ==============================
:: ArcOS Automatic Launcher
:: ==============================

echo.
echo =============================
echo        Starting ArcOS
echo =============================
echo.

:: --- Check for Administrator ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit
)

:: --- Move to script directory ---
cd /d "%~dp0"

:: --- Unblock files (in case downloaded from internet) ---
powershell -ExecutionPolicy Bypass -Command "Get-ChildItem -Path '%~dp0' -Recurse | Unblock-File"

:: --- Run ArcOS ---
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0main.ps1"

echo.
echo =============================
echo        ArcOS Finished
echo =============================
echo.

pause