# ===================================
# ArcOS - Windows Optimization Framework
# Version 0.5.0
# Beginner-Oriented Unified Build
# ===================================

$ArcOSVersion = "0.5.0"
$ErrorActionPreference = "Stop"

# ===============================
# Paths
# ===============================
$Global:LogPath   = "$PSScriptRoot\arcos.log"
$Global:StatePath = "$PSScriptRoot\state.json"

# ===============================
# Logging
# ===============================
function Write-ArcLog {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "[$Time] [$Level] $Message"

    Write-Host $Entry
    try { Add-Content -Path $Global:LogPath -Value $Entry } catch {}
}

# ===============================
# State Tracking
# ===============================
function Save-State {
    param (
        [string]$Key,
        [object]$Value
    )

    if (-not (Test-Path $Global:StatePath)) {
        '{}' | Out-File $Global:StatePath -Encoding utf8
    }

    try {
        $State = Get-Content $Global:StatePath -Raw | ConvertFrom-Json
    } catch {
        $State = @{}
    }

    $State | Add-Member -NotePropertyName $Key -NotePropertyValue $Value -Force
    $State | ConvertTo-Json -Depth 5 | Out-File $Global:StatePath -Encoding utf8
}

# ===============================
# Admin Check
# ===============================
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ArcOS must be run as Administrator."
    exit 1
}

Clear-Host
Write-Host "==================================="
Write-Host "         ArcOS $ArcOSVersion"
Write-Host "==================================="
Write-Host ""

Write-ArcLog "ArcOS started."

# ===============================
# Windows Detection
# ===============================
$WinInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$Build = [int]$WinInfo.CurrentBuild

Write-ArcLog "Edition: $($WinInfo.ProductName)"
Write-ArcLog "Version: $($WinInfo.DisplayVersion)"
Write-ArcLog "Build: $Build"

$Global:IsWindows11 = $Build -ge 22000
Write-ArcLog ($Global:IsWindows11 ? "Windows 11 detected." : "Windows 10 detected.")

# ===============================
# Auto Mode (Beginner Safe Default)
# ===============================
$ConfigPath = "$PSScriptRoot\config.json"

if (-not (Test-Path $ConfigPath)) {
    Write-ArcLog "config.json missing." "ERROR"
    exit 1
}

$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# Force balanced performance mode automatically
$Config.Mode = "Performance"
$Config.RemoveAppx = $true
$Config.OptimizeServices = $true
$Config.DisableTasks = $true
$Config.OptimizeUI = $true
$Config | ConvertTo-Json -Depth 5 | Set-Content $ConfigPath

Write-ArcLog "Automatic Performance mode enabled."

# ===============================
# Performance Snapshot (Before)
# ===============================
$PreProcesses = (Get-Process).Count
$PreServices  = (Get-Service).Count

Write-ArcLog "Pre-run processes: $PreProcesses"
Write-ArcLog "Pre-run services: $PreServices"

# ===============================
# Restore Point
# ===============================
try {
    Checkpoint-Computer -Description "ArcOS Restore Point" -RestorePointType "MODIFY_SETTINGS"
    Write-ArcLog "Restore point created."
}
catch {
    Write-ArcLog "Restore point creation failed." "WARN"
}

# ===============================
# Hardware Snapshot
# ===============================
$CPU = (Get-CimInstance Win32_Processor).Name
$RAM = [Math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$GPU = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name

Write-ArcLog "CPU: $CPU"
Write-ArcLog "RAM: $RAM GB"
Write-ArcLog "GPU: $GPU"

# ===============================
# Module Execution (All New Modules Included)
# ===============================
$Modules = Get-ChildItem "$PSScriptRoot\core\*.ps1" | Sort-Object Name

foreach ($Module in $Modules) {

    Write-ArcLog "Executing module: $($Module.Name)"

    try {
        . $Module.FullName
        Write-ArcLog "Completed: $($Module.Name)"
    }
    catch {
        Write-ArcLog "Failed: $($Module.Name) - $_" "ERROR"
    }
}

# ===============================
# Windows Update Integrity Check
# ===============================
try {
    $WU = Get-Service wuauserv
    Write-ArcLog "Windows Update status: $($WU.Status)"
}
catch {
    Write-ArcLog "Windows Update service issue detected." "ERROR"
}

# ===============================
# Performance Snapshot (After)
# ===============================
$PostProcesses = (Get-Process).Count
$PostServices  = (Get-Service).Count

Write-ArcLog "Post-run processes: $PostProcesses"
Write-ArcLog "Post-run services: $PostServices"

Write-ArcLog "Process difference: $($PreProcesses - $PostProcesses)"
Write-ArcLog "Service difference: $($PreServices - $PostServices)"

# ===============================
# Completion
# ===============================
Write-ArcLog "ArcOS finished successfully."

Write-Host ""
Write-Host "ArcOS optimization complete."
Write-Host ""