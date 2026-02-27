# ===================================
# ArcOS - Windows Optimization Framework
# ===================================

$ErrorActionPreference = "Stop"

# --- Admin Check ---
if (-not ([Security.Principal.WindowsPrincipal] `
[Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
[Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run ArcOS as Administrator."
    exit 1
}

# --- Logging ---
$LogPath = "$PSScriptRoot\arcos.log"
Start-Transcript -Path $LogPath -Append

Write-Host "Starting ArcOS..."

# --- Detect Windows Version ---
$WinInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
Write-Host "Detected Windows Version:" $WinInfo.DisplayVersion

# --- Create Restore Point ---
try {
    Checkpoint-Computer -Description "ArcOS Restore Point" -RestorePointType "MODIFY_SETTINGS"
    Write-Host "Restore point created."
} catch {
    Write-Host "Restore point could not be created."
}

# --- Load Config ---
$ConfigPath = "$PSScriptRoot\config.json"
$Config = Get-Content $ConfigPath | ConvertFrom-Json

# --- Run Modules ---
$Modules = Get-ChildItem -Path "$PSScriptRoot\core\*.ps1" | Sort-Object Name

foreach ($Module in $Modules) {
    Write-Host "Running $($Module.Name)..."
    . $Module.FullName
}

Write-Host "ArcOS finished successfully."
Stop-Transcript