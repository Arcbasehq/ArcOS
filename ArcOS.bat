@echo off
title ArcOS

:: ===================================
:: ArcOS Automatic Launcher
:: Beginner-Friendly Edition
:: ===================================

echo.
echo ===================================
echo              ArcOS
echo     Optimizing Your Windows PC
echo ===================================
echo.

:: --- Check for Administrator ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator permission...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit
)

:: --- Move to script directory ---
cd /d "%~dp0"

:: --- Unblock files (if downloaded) ---
powershell -ExecutionPolicy Bypass -Command "Get-ChildItem -Path '%~dp0' -Recurse | Unblock-File"

echo.
echo Checking system health...
echo.

:: --- Quick System Health Check ---
powershell -ExecutionPolicy Bypass -NoProfile -Command ^
"$issues = 0; ^
if (-not (Get-Service wuauserv -ErrorAction SilentlyContinue)) { $issues++ }; ^
if (-not (Get-Service WinDefend -ErrorAction SilentlyContinue)) { $issues++ }; ^
if ($issues -gt 0) { Write-Host 'Warning: Some system components may be disabled.' -ForegroundColor Yellow } else { Write-Host 'System looks healthy.' -ForegroundColor Green }"

echo.
echo Preparing optimization settings...
echo.

:: --- Automatically Configure Performance Mode & Enable New Features ---
powershell -ExecutionPolicy Bypass -NoProfile -Command ^
"$config = Get-Content '%~dp0config.json' -Raw | ConvertFrom-Json; ^
$config.Mode = 'Performance'; ^
$config.RemoveAppx = $true; ^
$config.OptimizeServices = $true; ^
$config.DisableTasks = $true; ^
$config.OptimizeUI = $true; ^
$config | ConvertTo-Json -Depth 5 | Set-Content '%~dp0config.json'"

echo Running ArcOS optimization...
echo Please wait...
echo.

:: --- Run ArcOS Framework ---
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0main.ps1"

echo.
echo ===================================
echo      Optimization Complete
echo      Restarting Your PC...
echo ===================================
echo.

timeout /t 5 >nul
shutdown /r /t 0