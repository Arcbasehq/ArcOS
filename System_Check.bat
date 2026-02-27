@echo off
title ArcOS System Safety Check

echo.
echo ===================================
echo      ArcOS System Safety Check
echo ===================================
echo.

:: --- Admin Check ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Please run as Administrator.
    pause
    exit
)

powershell -ExecutionPolicy Bypass -NoProfile -Command ^
""

Write-Host ''
Write-Host 'Running system integrity checks...' -ForegroundColor Cyan

$Issues = 0

# -------------------------------
# 1. Windows Update Service
# -------------------------------
$WU = Get-Service wuauserv -ErrorAction SilentlyContinue
if ($WU -and ($WU.Status -eq 'Running' -or $WU.Status -eq 'Stopped')) {
    Write-Host 'Windows Update: OK' -ForegroundColor Green
} else {
    Write-Host 'Windows Update: PROBLEM' -ForegroundColor Red
    $Issues++
}

# -------------------------------
# 2. Defender Service
# -------------------------------
$Def = Get-Service WinDefend -ErrorAction SilentlyContinue
if ($Def -and ($Def.Status -eq 'Running' -or $Def.Status -eq 'Stopped')) {
    Write-Host 'Windows Defender: OK' -ForegroundColor Green
} else {
    Write-Host 'Windows Defender: PROBLEM' -ForegroundColor Red
    $Issues++
}

# -------------------------------
# 3. Servicing Stack Health
# -------------------------------
Write-Host 'Checking component store health...'
$dism = dism /online /cleanup-image /checkhealth

if ($LASTEXITCODE -eq 0) {
    Write-Host 'Component Store: OK' -ForegroundColor Green
} else {
    Write-Host 'Component Store: WARNING' -ForegroundColor Yellow
    $Issues++
}

# -------------------------------
# 4. System File Check
# -------------------------------
Write-Host 'Checking system files...'
$sfc = sfc /verifyonly

if ($LASTEXITCODE -eq 0) {
    Write-Host 'System Files: OK' -ForegroundColor Green
} else {
    Write-Host 'System Files: CORRUPTION DETECTED' -ForegroundColor Red
    $Issues++
}

# -------------------------------
# 5. Disk Health
# -------------------------------
Write-Host 'Checking disk health...'
$disk = Get-PhysicalDisk | Where-Object { $_.HealthStatus -ne 'Healthy' }

if (-not $disk) {
    Write-Host 'Disk Health: OK' -ForegroundColor Green
} else {
    Write-Host 'Disk Health: WARNING' -ForegroundColor Yellow
    $Issues++
}

Write-Host ''
Write-Host '==================================='

if ($Issues -eq 0) {
    Write-Host 'SYSTEM STATUS: SAFE' -ForegroundColor Green
}
elseif ($Issues -le 2) {
    Write-Host 'SYSTEM STATUS: WARNING' -ForegroundColor Yellow
}
else {
    Write-Host 'SYSTEM STATUS: CRITICAL' -ForegroundColor Red
}

Write-Host '==================================='
""

echo.
pause