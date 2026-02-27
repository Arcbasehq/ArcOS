@echo off
setlocal EnableExtensions
title ArcOS

:: ===================================
:: ArcOS Automatic Launcher
:: Stable Production Version
:: ===================================

echo.
echo ===================================
echo              ArcOS
echo     Optimizing Your Windows PC
echo ===================================
echo.

:: -------------------------------
:: Admin Check
:: -------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator permission...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: -------------------------------
:: Move to Script Directory
:: -------------------------------
cd /d "%~dp0"

:: -------------------------------
:: Unblock Files (Safe)
:: -------------------------------
powershell -ExecutionPolicy Bypass -NoProfile -Command ^
"Get-ChildItem -Path '%~dp0' -Recurse -ErrorAction SilentlyContinue | Unblock-File" >nul 2>&1

echo.
echo Checking system health...
echo.

:: -------------------------------
:: System Health Check
:: -------------------------------
powershell -ExecutionPolicy Bypass -NoProfile -Command ^
"$issues = 0; ^
$wu = Get-Service wuauserv -ErrorAction SilentlyContinue; ^
$def = Get-Service WinDefend -ErrorAction SilentlyContinue; ^
if (-not $wu) { $issues++ }; ^
if (-not $def) { $issues++ }; ^
if ($issues -gt 0) { Write-Host 'Warning: Some core services may be disabled.' -ForegroundColor Yellow } ^
else { Write-Host 'System looks healthy.' -ForegroundColor Green }"

echo.
echo Preparing optimization settings...
echo.

:: -------------------------------
:: Configure Performance Mode
:: -------------------------------
powershell -ExecutionPolicy Bypass -NoProfile -Command ^
"if (Test-Path '%~dp0config.json') { ^
$config = Get-Content '%~dp0config.json' -Raw | ConvertFrom-Json; ^
$config.Mode = 'Performance'; ^
$config.RemoveAppx = $true; ^
$config.OptimizeServices = $true; ^
$config.DisableTasks = $true; ^
$config.OptimizeUI = $true; ^
$config | ConvertTo-Json -Depth 5 | Set-Content '%~dp0config.json' ^
} else { Write-Host 'config.json missing.' -ForegroundColor Red; exit 1 }"

if %errorlevel% neq 0 (
    echo Failed to configure settings.
    pause
    exit /b
)

echo.
echo Running ArcOS optimization...
echo Please wait...
echo.

:: -------------------------------
:: Run Main Framework
:: -------------------------------
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0main.ps1"

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
echo Your PC will restart in 10 seconds...
echo Press Ctrl+C now to cancel.
echo.

timeout /t 10

shutdown /r /t 0