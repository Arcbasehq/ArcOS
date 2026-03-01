$ErrorActionPreference = 'Stop'

# =====================================================
# Command Line Arguments
# =====================================================

$rollbackMode = $false
$rollbackFile = "rollback-latest.json"

# Parse command line arguments
for ($i = 0; $i -lt $args.Length; $i++) {
    switch ($args[$i]) {
        "--rollback" {
            $rollbackMode = $true
            if ($i + 1 -lt $args.Length -and $args[$i + 1] -notlike "-") {
                $rollbackFile = $args[$i + 1]
                $i++
            }
        }
        "--help" {
            Show-Help
            exit 0
        }
        "--version" {
            Write-Host "ArcOS Framework v1.0"
            exit 0
        }
    }
}

function Show-Help {
    Write-Host ""
    Write-Host "ArcOS Framework - Windows Optimization Tool" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Green
    Write-Host "  .\main.ps1 [options]"
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Green
    Write-Host "  --rollback [file]    Rollback system to previous state"
    Write-Host "  --help               Show this help message"
    Write-Host "  --version            Show version information"
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Green
    Write-Host "  Edit config.json to customize optimization settings"
    Write-Host ""
    Write-Host "Profiles:" -ForegroundColor Green
    Write-Host "  balanced     - Recommended settings for most users"
    Write-Host "  aggressive   - Maximum performance optimizations"
    Write-Host "  stable       - Conservative optimizations only"
    Write-Host "  performance  - Focus on performance improvements"
    Write-Host ""
}

# =====================================================
# Paths
# =====================================================

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$enginePath = Join-Path $root 'engine'
$reportPath = Join-Path $root 'reports'
$manifest = Join-Path $enginePath 'engine.manifest.json'

if (-not (Test-Path $reportPath)) {
    New-Item -ItemType Directory -Path $reportPath | Out-Null
}

if ($rollbackMode) {
    Write-Host "Rolling back system state..." -ForegroundColor Yellow
    try {
        . "$enginePath\rollback.ps1"
        $result = Apply-Rollback -RollbackFile $rollbackFile
        if ($result) {
            Write-Host "Rollback completed successfully." -ForegroundColor Green
        }
        else {
            Write-Host "Rollback failed." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Rollback error: $($_.Exception.Message)" -ForegroundColor Red
    }
    exit 0
}

# =====================================================
# Load Core Modules
# =====================================================

. "$enginePath\logger.ps1"
. "$enginePath\precheck.ps1"
. "$enginePath\rollback.ps1"
. "$enginePath\postcheck.ps1"

# Load Engines
Get-ChildItem "$enginePath\*-engine.ps1" | ForEach-Object {
    . $_.FullName
}

# =====================================================
# Admin Validation
# =====================================================

function Show-ErrorMessage {
    param (
        [string]$Message,
        [string]$Details
    )
    
    Write-Host "" 
    Write-Host "ERROR: $Message" -ForegroundColor Red
    if ($Details) {
        Write-Host "Details: $Details" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Show-WarningMessage {
    param (
        [string]$Message
    )
    
    Write-Host "WARNING: $Message" -ForegroundColor Yellow
}

function Show-SuccessMessage {
    param (
        [string]$Message
    )
    
    Write-Host "SUCCESS: $Message" -ForegroundColor Green
}

function Show-InfoMessage {
    param (
        [string]$Message
    )
    
    Write-Host "INFO: $Message" -ForegroundColor Cyan
}

if ($IsWindows) {
    $principal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )

    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Show-ErrorMessage -Message "ArcOS must be run as Administrator." -Details "Please right-click and select 'Run as Administrator'"
        exit 1
    }
}
else {
    Show-WarningMessage -Message "Admin check skipped (non-Windows platform)."
}

# =====================================================
# Windows Build Detection
# =====================================================

try {
    $Build = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
    $Global:CurrentBuild = $Build
    Show-InfoMessage -Message "Detected Windows build: $Build"
}
catch {
    Show-ErrorMessage -Message "Failed to detect Windows build." -Details $_.Exception.Message
    exit 1
}

# =====================================================
# Configuration Loading
# =====================================================

$configPath = Join-Path $root "config.json"

function Test-Configuration {
    param (
        [object]$ConfigToValidate
    )
    
    $errors = @()
    
    # Check required fields
    if (-not $ConfigToValidate.version) { $errors += "Missing 'version' field" }
    if (-not $ConfigToValidate.profile) { $errors += "Missing 'profile' field" }
    if (-not $ConfigToValidate.engines) { $errors += "Missing 'engines' field" }
    if (-not $ConfigToValidate.advanced) { $errors += "Missing 'advanced' field" }
    
    # Validate profile
    $validProfiles = "balanced", "aggressive", "stable", "performance"
    if ($validProfiles -notcontains $ConfigToValidate.profile) {
        $errors += "Invalid profile: '$($ConfigToValidate.profile)'. Valid options: $($validProfiles -join ', ')"
    }
    
    # Validate engines section - use the engines from config since EngineManifest might not be loaded yet
    foreach ($engineName in $ConfigToValidate.engines.Keys) {
        if (-not $ConfigToValidate.engines.$engineName) {
            $errors += "Missing configuration for engine: $engineName"
        }
        elseif (-not [bool]::TryParse($ConfigToValidate.engines.$engineName.enabled.ToString(), [ref]$null)) {
            $errors += "Invalid 'enabled' value for engine $engineName (must be boolean)"
        }
    }
    
    # Validate advanced settings
    $advancedKeys = "createRestorePoint", "skipCompatibilityCheck", "dryRunMode", "verboseLogging", "autoReboot"
    foreach ($key in $advancedKeys) {
        if (-not [bool]::TryParse($ConfigToValidate.advanced.$key.ToString(), [ref]$null)) {
            $errors += "Invalid '$key' value in advanced settings (must be boolean)"
        }
    }
    
    return $errors
}

if (-not (Test-Path $configPath)) {
    Write-Host "Configuration file missing. Creating default config..."
    # Create default config
    $defaultConfig = @{
        version  = "1.0"
        profile  = "balanced"
        engines  = @{}
        advanced = @{
            createRestorePoint     = $true
            skipCompatibilityCheck = $false
            dryRunMode             = $false
            verboseLogging         = $false
            autoReboot             = $true
        }
    }
    
    # Enable all engines by default - use known engine list since manifest might not be loaded
    $defaultEngines = @(
        "ServiceEngine", "TaskEngine", "AppxEngine", "RegistryEngine", "PolicyEngine",
        "PerformanceEngine", "UIEngine", "WallpaperEngine", "AvatarEngine", "OneDriveEngine", "EdgeEngine"
    )
    
    foreach ($engine in $defaultEngines) {
        $defaultConfig.engines.$engine = @{
            enabled = $true
            config  = @{}
        }
    }
    
    $defaultConfig | ConvertTo-Json -Depth 10 | Out-File $configPath
    Write-Host "Default configuration created. Please review config.json and run again."
    exit 0
}

try {
    $Config = Get-Content $configPath -Raw | ConvertFrom-Json
    
    # Validate configuration
    $validationErrors = Test-Configuration -ConfigToValidate $Config
    
    if ($validationErrors.Count -gt 0) {
        Write-Host "Configuration validation errors:" -ForegroundColor Red
        foreach ($validationError in $validationErrors) {
            Write-Host "  - $validationError" -ForegroundColor Red
        }
        exit 1
    }
    
    Write-ArcLog "Configuration loaded and validated successfully"
}
catch {
    Write-Host "Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# =====================================================
# Metadata + Risk Handling
# =====================================================

$RiskOrder = @{
    "Stable"       = 1
    "Performance"  = 2
    "Minimal"      = 3
    "Experimental" = 4
}

$SelectedProfile = $Config.profile
if (-not $SelectedProfile) {
    $SelectedProfile = "balanced"
}

if (-not (Test-Path $manifest)) {
    Write-Host "Engine manifest missing."
    exit 1
}

$EngineManifest = Get-Content $manifest -Raw | ConvertFrom-Json

# =====================================================
# Playbook Integration
# =====================================================

function Import-Playbook {
    param (
        [string]$PlaybookName
    )
    
    $playbookPath = Join-Path $root "playbooks" "$PlaybookName.json"
    
    if (Test-Path $playbookPath) {
        return Get-Content $playbookPath -Raw | ConvertFrom-Json
    }
    
    return $null
}

# Try to load the playbook based on profile
$Playbook = Import-Playbook -PlaybookName $SelectedProfile

if (-not $Playbook) {
    Write-ArcLog "Playbook '$SelectedProfile' not found, using default engine order" "WARN"
    $EnginesToRun = @(
        "ServiceEngine",
        "TaskEngine",
        "AppxEngine",
        "RegistryEngine",
        "PolicyEngine",
        "UIEngine",
        "AvatarEngine",
        "PerformanceEngine",
        "WallpaperEngine",
        "OneDriveEngine",
        "EdgeEngine"
    )
}
else {
    Write-ArcLog "Using playbook: $($Playbook.name)"
    $EnginesToRun = $Playbook.engines
}

# =====================================================
# Engine Execution Wrapper
# =====================================================

$Global:RebootRequired = $false
$ExecutionReport = @()

function Invoke-EngineSafely {
    param (
        [string]$EngineName
    )

    if (-not $EngineManifest.$EngineName) {
        Write-ArcLog "$EngineName missing metadata." "WARN"
        return
    }

    $Meta = $EngineManifest.$EngineName
    $EngineConfig = $Config.engines.$EngineName.config

    if ($Global:CurrentBuild -lt $Meta.minBuild) {
        Write-ArcLog "$EngineName skipped (unsupported build)."
        return
    }

    if ($RiskOrder[$Meta.risk] -gt $RiskOrder[$SelectedProfile]) {
        Write-ArcLog "$EngineName skipped (risk tier)."
        return
    }

    $FunctionName = "Invoke-$EngineName"

    if (-not (Get-Command $FunctionName -ErrorAction SilentlyContinue)) {
        Write-ArcLog "$FunctionName not found." "ERROR"
        return
    }

    try {
        Write-ArcLog "Executing $EngineName"
        
        # Pass configuration to engine
        if ($EngineConfig) {
            & $FunctionName -Config $EngineConfig
        }
        else {
            & $FunctionName
        }

        if ($Meta.requiresReboot) {
            $Global:RebootRequired = $true
        }

        $ExecutionReport += @{
            Engine = $EngineName
            Status = "Success"
        }

        Write-ArcLog "$EngineName completed."
    }
    catch {
        Write-ArcLog "$EngineName failed: $($_.Exception.Message)" "ERROR"

        $ExecutionReport += @{
            Engine = $EngineName
            Status = "Failed"
        }
    }
}

# =====================================================
# Deployment Start
# =====================================================

Write-ArcLog "ArcOS deployment starting with profile: $SelectedProfile"
Invoke-Precheck
Initialize-Rollback

foreach ($Engine in $EnginesToRun) {
    # Check if engine is enabled in config
    if ($Config.engines.$Engine.enabled -eq $false) {
        Write-ArcLog "$Engine skipped (disabled in config)"
        continue
    }
    
    Invoke-EngineSafely -EngineName $Engine
}

Invoke-Postcheck

# =====================================================
# Reporting
# =====================================================

$ReportData = @{
    Timestamp     = Get-Date
    WindowsBuild  = $Global:CurrentBuild
    Profile       = $SelectedProfile
    Processes     = (Get-Process).Count
    Services      = (Get-Service).Count
    RAM_Used_MB   = [math]::Round(
        ((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize -
        (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory) / 1024
    )
    Engines       = $ExecutionReport
    Configuration = @{
        Profile          = $Config.profile
        AdvancedSettings = $Config.advanced
        EngineSettings   = @{}
    }
}

# Add enabled/disabled status for each engine
foreach ($engine in $EngineManifest.Keys) {
    $engineSettings = @{
        Enabled = $Config.engines.$engine.enabled
        Config  = $Config.engines.$engine.config
    }
    $ReportData.Configuration.EngineSettings.Add($engine, $engineSettings)
}

$ReportData | ConvertTo-Json -Depth 10 |
Out-File (Join-Path $reportPath "deployment.json")

Write-ArcLog "ArcOS deployment complete. Report saved to $reportPath\deployment.json"

# Save configuration backup
$Config | ConvertTo-Json -Depth 10 |
Out-File (Join-Path $reportPath "config-backup.json")

# =====================================================
# Controlled Restart
# =====================================================

if ($Global:RebootRequired -and $Config.advanced.autoReboot) {
    Write-Host ""
    Write-Host "Reboot required. Restarting in 5 seconds..."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
}
elseif ($Global:RebootRequired) {
    Write-Host ""
    Write-Host "Reboot required but auto-reboot disabled. Please restart manually."
}
else {
    Write-Host ""
    Write-Host "ArcOS completed successfully. No reboot required."
}

Write-Host ""
Write-Host "Summary:"
Write-Host "- Profile used: $SelectedProfile"
Write-Host "- Engines executed: $($ExecutionReport.Count)"
Write-Host "- Successful: $($ExecutionReport.Where({$_.Status -eq 'Success'}).Count)"
Write-Host "- Failed: $($ExecutionReport.Where({$_.Status -eq 'Failed'}).Count)"
Write-Host "- Report location: $reportPath\deployment.json"