$ErrorActionPreference = 'Stop'

# =====================================================
# Admin Check
# =====================================================

$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ArcOS must be run as Administrator."
    exit 1
}

# =====================================================
# Paths
# =====================================================

$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$engine = Join-Path $root 'engine'

# =====================================================
# Load Engines
# =====================================================

. "$engine\logger.ps1"
. "$engine\precheck.ps1"
. "$engine\rollback.ps1"
. "$engine\service-engine.ps1"
. "$engine\task-engine.ps1"
. "$engine\appx-engine.ps1"
. "$engine\registry-engine.ps1"
. "$engine\policy-engine.ps1"
. "$engine\postcheck.ps1"
. "$engine\avatar-engine.ps1"
. "$engine\performance-engine.ps1"
. "$engine\ui-engine.ps1"
. "$engine\wallpaper-engine.ps1"
. "$engine\onedrive-engine.ps1"

# =====================================================
# Deployment Start
# =====================================================

Write-ArcLog "ArcOS deployment starting."

Invoke-Precheck
Initialize-Rollback

# Run OneDrive removal early
try {
    Invoke-OneDriveEngine
    Write-ArcLog "OneDriveEngine completed."
}
catch {
    Write-ArcLog "OneDriveEngine failed: $($_.Exception.Message)" "ERROR"
}

# =====================================================
# Engine Execution
# =====================================================

$EngineFunctions = @(
    "Invoke-ServiceEngine",
    "Invoke-TaskEngine",
    "Invoke-AppxEngine",
    "Invoke-RegistryEngine",
    "Invoke-PolicyEngine",
    "Invoke-AvatarEngine",
    "Invoke-PerformanceEngine",
    "Invoke-UIEngine",
    "Invoke-WallpaperEngine"
)

foreach ($FunctionName in $EngineFunctions) {
    try {
        & $FunctionName
        Write-ArcLog "$FunctionName completed."
    }
    catch {
        Write-ArcLog "$FunctionName failed: $($_.Exception.Message)" "ERROR"
    }
}

Invoke-Postcheck

# =====================================================
# Completion
# =====================================================

Write-ArcLog "ArcOS deployment complete."
Write-Host ""
Write-Host "ArcOS optimization complete."
Write-Host "System will restart in 5 seconds..."

Start-Sleep -Seconds 5
Restart-Computer -Force