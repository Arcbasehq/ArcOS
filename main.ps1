# ===================================
# ArcOS - Windows Optimization Framework
# Version 0.5.2
# ===================================

$ArcOSVersion = "0.5.2"
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
    try { Add-Content -Path $Global:LogPath -Value $Entry -ErrorAction SilentlyContinue } catch {}
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

if ($Global:IsWindows11) {
    Write-ArcLog "Windows 11 detected."
}
else {
    Write-ArcLog "Windows 10 detected."
}

# ===============================
# Load / Create Config Safely
# ===============================
$ConfigPath = "$PSScriptRoot\config.json"

if (-not (Test-Path $ConfigPath)) {
    '{}' | Out-File $ConfigPath -Encoding utf8
}

try {
    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
} catch {
    $Config = @{}
}

# Ensure object type
if ($Config -eq $null) { $Config = @{} }

# Safely add properties if missing
if (-not $Config.PSObject.Properties["Mode"]) {
    $Config | Add-Member -NotePropertyName Mode -NotePropertyValue "Performance"
} else {
    $Config.Mode = "Performance"
}

if (-not $Config.PSObject.Properties["RemoveAppx"]) {
    $Config | Add-Member -NotePropertyName RemoveAppx -NotePropertyValue $true
} else {
    $Config.RemoveAppx = $true
}

if (-not $Config.PSObject.Properties["OptimizeServices"]) {
    $Config | Add-Member -NotePropertyName OptimizeServices -NotePropertyValue $true
} else {
    $Config.OptimizeServices = $true
}

if (-not $Config.PSObject.Properties["DisableTasks"]) {
    $Config | Add-Member -NotePropertyName DisableTasks -NotePropertyValue $true
} else {
    $Config.DisableTasks = $true
}

if (-not $Config.PSObject.Properties["OptimizeUI"]) {
    $Config | Add-Member -NotePropertyName OptimizeUI -NotePropertyValue $true
} else {
    $Config.OptimizeUI = $true
}

$Config | ConvertTo-Json -Depth 5 | Set-Content $ConfigPath -Encoding utf8

Write-ArcLog "Configuration prepared."

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
# Module Execution
# ===============================
$Modules = Get-ChildItem "$PSScriptRoot\core\*.ps1" -ErrorAction SilentlyContinue | Sort-Object Name

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
# Performance Snapshot (After)
# ===============================
$PostProcesses = (Get-Process).Count
$PostServices  = (Get-Service).Count

Write-ArcLog "Post-run processes: $PostProcesses"
Write-ArcLog "Post-run services: $PostServices"
Write-ArcLog "Process difference: $($PreProcesses - $PostProcesses)"
Write-ArcLog "Service difference: $($PreServices - $PostServices)"

Write-ArcLog "ArcOS finished successfully."

Write-Host ""
Write-Host "ArcOS optimization complete."
Write-Host ""