#!/usr/bin/env pwsh
<#
.SYNOPSIS
    ArcOS ABPX Wizard — reads a .abpx bundle and applies optimizations interactively.

.DESCRIPTION
    Loads a .abpx file, shows the user what engines and tweaks are included,
    lets them customize what to run, then applies the changes.

.PARAMETER File
    Path to the .abpx file. If omitted, prompts with a file browser.

.PARAMETER DryRun
    Preview changes without applying anything.

.EXAMPLE
    .\wizard.ps1 --file dist\arc-gaming.abpx
    .\wizard.ps1 --file dist\arc-gaming.abpx --DryRun
#>

param (
    [string]$File,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# =====================================================
# Colours + Banner
# =====================================================

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║          ArcOS — ABPX Wizard  v1.0          ║" -ForegroundColor Cyan
    Write-Host "  ║      Windows Optimization Bundle Reader      ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step ([int]$n, [string]$title) {
    Write-Host ""
    Write-Host "  ── Step $n — $title" -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-Good  ([string]$m) { Write-Host "  ✓  $m" -ForegroundColor Green }
function Write-Info  ([string]$m) { Write-Host "  →  $m" -ForegroundColor Cyan }
function Write-Warn  ([string]$m) { Write-Host "  ⚠  $m" -ForegroundColor Yellow }
function Write-Fail  ([string]$m) { Write-Host "  ✗  $m" -ForegroundColor Red }
function Write-Sep { Write-Host "  ────────────────────────────────────────" -ForegroundColor DarkGray }

# =====================================================
# Admin Check
# =====================================================

Write-Banner

if ($IsWindows) {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Fail "Please run this wizard as Administrator."
        Write-Host ""
        exit 1
    }
    Write-Good "Running as Administrator."
}
else {
    Write-Warn "Non-Windows platform — registry/service changes will be skipped."
}

# =====================================================
# Step 1 — Select .abpx File
# =====================================================

Write-Step 1 "Select ABPX Bundle"

if (-not $File) {
    Write-Info "Enter the path to your .abpx file:"
    Write-Host "  " -NoNewline
    $File = Read-Host
}

$File = $File.Trim().Trim('"')

if (-not (Test-Path $File)) {
    Write-Fail "File not found: $File"
    exit 1
}

if (-not $File.EndsWith(".abpx")) {
    Write-Warn "File does not have .abpx extension, but attempting to read anyway."
}

Write-Good "Bundle found: $File"

# =====================================================
# Step 2 — Extract and Validate Bundle
# =====================================================

Write-Step 2 "Reading Bundle"

Add-Type -AssemblyName System.IO.Compression.FileSystem

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "arcos-abpx-$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($File, $TempDir)
    Write-Good "Bundle extracted to temp directory."
}
catch {
    Write-Fail "Failed to read .abpx file: $($_.Exception.Message)"
    Write-Warn "Make sure the file is a valid .abpx bundle built by build_abpx.py."
    exit 1
}

# Read header
$ManifestPath = Join-Path $TempDir "arcos.manifest.json"
if (-not (Test-Path $ManifestPath)) {
    Write-Fail "Invalid bundle: missing arcos.manifest.json header."
    Remove-Item $TempDir -Recurse -Force
    exit 1
}

$BundleMeta = Get-Content $ManifestPath -Raw | ConvertFrom-Json

# ── SHA-256 integrity check ──
Write-Info "Verifying file integrity..."
$integrityOk = $true
foreach ($entry in $BundleMeta.files) {
    $filePath = Join-Path $TempDir $entry.path.Replace("/", [IO.Path]::DirectorySeparatorChar)
    if (Test-Path $filePath) {
        $actualHash = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash.ToLower()
        if ($actualHash -ne $entry.sha256) {
            Write-Warn "Checksum mismatch: $($entry.path)"
            $integrityOk = $false
        }
    }
    else {
        Write-Warn "Listed file missing from bundle: $($entry.path)"
        $integrityOk = $false
    }
}

if ($integrityOk) {
    Write-Good "All file checksums verified."
}
else {
    Write-Warn "Some files failed integrity check. The bundle may have been modified."
    Write-Host ""
    Write-Host "  Continue anyway? (y/N): " -NoNewline -ForegroundColor Yellow
    $confirm = Read-Host
    if ($confirm -notmatch "^[yY]") { exit 1 }
}

# =====================================================
# Step 3 — Show Bundle Info
# =====================================================

Write-Step 3 "Bundle Information"

Write-Sep
Write-Host "  Name        : " -NoNewline; Write-Host $BundleMeta.name -ForegroundColor White
Write-Host "  Description : " -NoNewline; Write-Host $BundleMeta.description -ForegroundColor White
Write-Host "  Author      : " -NoNewline; Write-Host $BundleMeta.author -ForegroundColor White
Write-Host "  Built       : " -NoNewline; Write-Host $BundleMeta.built_at -ForegroundColor White
Write-Host "  ABPX ver    : " -NoNewline; Write-Host $BundleMeta.abpx_version -ForegroundColor White
Write-Sep
Write-Host "  Playbooks   : " -NoNewline; Write-Host ($BundleMeta.playbooks -join ", ") -ForegroundColor Magenta
Write-Host "  Engines     : " -NoNewline; Write-Host ($BundleMeta.engines -join ", ") -ForegroundColor Yellow
Write-Host "  Files       : " -NoNewline; Write-Host "$($BundleMeta.stats.total_files) bundled" -ForegroundColor Gray
Write-Sep

# Count tweaks from manifests
$regCount = 0; $polCount = 0; $taskCount = 0; $svcCount = 0
$regPath = Join-Path $TempDir "manifests\registry.json"
$polPath = Join-Path $TempDir "manifests\policies.json"
$taskPath = Join-Path $TempDir "manifests\tasks.json"
$svcPath = Join-Path $TempDir "manifests\services.json"

if (Test-Path $regPath) { $regCount = (Get-Content $regPath  -Raw | ConvertFrom-Json).Count }
if (Test-Path $polPath) { $polCount = (Get-Content $polPath  -Raw | ConvertFrom-Json).Count }
if (Test-Path $taskPath) { $taskCount = (Get-Content $taskPath -Raw | ConvertFrom-Json).Count }
if (Test-Path $svcPath) { $svcCount = (Get-Content $svcPath  -Raw | ConvertFrom-Json).Count }

Write-Host "  Tweaks      : " -NoNewline
Write-Host "$regCount registry  |  $polCount policies  |  $taskCount tasks  |  $svcCount services" -ForegroundColor Cyan
Write-Sep

if ($DryRun) {
    Write-Host "  Mode        : " -NoNewline
    Write-Host "DRY RUN — no changes will be applied" -ForegroundColor Yellow
    Write-Sep
}

# =====================================================
# Step 4 — Engine Selection
# =====================================================

Write-Step 4 "Select Engines to Run"

Write-Info "Use the numbers below to toggle engines on/off. Press ENTER when done."
Write-Host ""

# Build interactive checklist from the bundle's engine list
$engineList = $BundleMeta.engines | ForEach-Object { @{ Name = $_; Enabled = $true } }

$done = $false
while (-not $done) {
    Write-Host "  ┌──────────────────────────────────────────┐" -ForegroundColor DarkGray
    for ($i = 0; $i -lt $engineList.Count; $i++) {
        $e = $engineList[$i]
        $check = if ($e.Enabled) { "✓" } else { " " }
        $color = if ($e.Enabled) { "Green" } else { "DarkGray" }
        Write-Host "  │  [$check] $($i+1). $($e.Name)" -ForegroundColor $color
    }
    Write-Host "  └──────────────────────────────────────────┘" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Toggle [#], or press ENTER to continue: " -NoNewline -ForegroundColor Cyan
    $userChoice = Read-Host

    if ([string]::IsNullOrWhiteSpace($userChoice)) {
        $done = $true
    }
    elseif ($userChoice -match "^\d+$") {
        $idx = [int]$userChoice - 1
        if ($idx -ge 0 -and $idx -lt $engineList.Count) {
            $engineList[$idx].Enabled = -not $engineList[$idx].Enabled
        }
    }

    if (-not $done) { Write-Host "" }
}

$selectedEngines = $engineList | Where-Object { $_.Enabled } | ForEach-Object { $_.Name }

if ($selectedEngines.Count -eq 0) {
    Write-Warn "No engines selected. Exiting."
    Remove-Item $TempDir -Recurse -Force
    exit 0
}

Write-Good "Selected: $($selectedEngines -join ', ')"

# =====================================================
# Step 5 — Confirmation
# =====================================================

Write-Step 5 "Confirmation"

Write-Sep
Write-Host "  The following changes will be applied:" -ForegroundColor White
Write-Host ""
if ($selectedEngines -contains "RegistryEngine") { Write-Info "$regCount registry keys will be set" }
if ($selectedEngines -contains "PolicyEngine") { Write-Info "$polCount group policy rules will be applied" }
if ($selectedEngines -contains "TaskEngine") { Write-Info "$taskCount scheduled tasks will be disabled" }
if ($selectedEngines -contains "ServiceEngine") { Write-Info "$svcCount services will be modified" }
Write-Sep

if (-not $DryRun) {
    Write-Host "  Apply all changes? (y/N): " -NoNewline -ForegroundColor Yellow
    $confirm = Read-Host
    if ($confirm -notmatch "^[yY]") {
        Write-Info "Cancelled."
        Remove-Item $TempDir -Recurse -Force
        exit 0
    }
}

# =====================================================
# Step 6 — Apply Bundle
# =====================================================

Write-Step 6 "$(if ($DryRun) { 'Dry Run Preview' } else { 'Applying Changes' })"

# Set up paths so the engines can find manifests
$Global:CurrentBuild = 0
if ($IsWindows) {
    try {
        $Global:CurrentBuild = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
    }
    catch {}
}

# Load logger from bundle
$loggerPath = Join-Path $TempDir "engines\logger.ps1"
if (Test-Path $loggerPath) { . $loggerPath }
else {
    function Write-ArcLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "  [$Level] $Message" -ForegroundColor $(
            switch ($Level) { "ERROR" { "Red" } "WARN" { "Yellow" } default { "Gray" } }
        )
    }
}

# Override manifest path for extracted bundle
$engineDir = Join-Path $TempDir "engines"
$manifestDir = Join-Path $TempDir "manifests"

# Load rollback first (if available and not dry-run)
if (-not $DryRun) {
    $rollbackPath = Join-Path $engineDir "rollback.ps1"
    if (Test-Path $rollbackPath) {
        . $rollbackPath
        try { Initialize-Rollback } catch { Write-Warn "Rollback init failed: $($_.Exception.Message)" }
    }
}

# Load and run only selected engines
$engineFileMap = @{
    "ServiceEngine"     = "service-engine.ps1"
    "TaskEngine"        = "task-engine.ps1"
    "AppxEngine"        = "appx-engine.ps1"
    "RegistryEngine"    = "registry-engine.ps1"
    "PolicyEngine"      = "policy-engine.ps1"
    "PerformanceEngine" = "performance-engine.ps1"
    "UIEngine"          = "ui-engine.ps1"
    "WallpaperEngine"   = "wallpaper-engine.ps1"
    "AvatarEngine"      = "avatar-engine.ps1"
    "OneDriveEngine"    = "onedrive-engine.ps1"
    "EdgeEngine"        = "edge-engine.ps1"
    "NetworkEngine"     = "network-engine.ps1"
    "GamingEngine"      = "gaming-engine.ps1"
}

# Patch engines to use extracted manifest dir
$env:ARCOS_MANIFEST_DIR = $manifestDir

foreach ($engName in $selectedEngines) {
    $fname = $engineFileMap[$engName]
    if (-not $fname) { Write-Warn "No file mapping for $engName"; continue }

    $engPath = Join-Path $engineDir $fname
    if (-not (Test-Path $engPath)) { Write-Warn "Engine not in bundle: $fname"; continue }

    Write-Host ""
    Write-Host "  ▶ Running $engName..." -ForegroundColor Magenta

    if ($DryRun) {
        Write-Info "[DRY RUN] Would execute: $fname"
        continue
    }

    try {
        # Load engine (patch PSScriptRoot-based manifest paths to use extracted dir)
        $engineContent = Get-Content $engPath -Raw
        $engineContent = $engineContent -replace [regex]::Escape('$PSScriptRoot + ''\..\manifests\'''), "`"$manifestDir\`""
        $engineContent = $engineContent -replace [regex]::Escape('$PSScriptRoot + "\..\manifests\"'), "`"$manifestDir\`""
        $engineContent = $engineContent -replace 'Join-Path \$PSScriptRoot ''\.\.\\manifests\\', "Join-Path `"$manifestDir`" '"
        $engineContent = $engineContent -replace "Join-Path \`$PSScriptRoot '\.\.\\\\manifests\\\\", "Join-Path `"$manifestDir`" '"

        $scriptBlock = [ScriptBlock]::Create($engineContent)
        . $scriptBlock

        $funcName = "Invoke-$engName"
        if (Get-Command $funcName -ErrorAction SilentlyContinue) {
            & $funcName
        }
        else {
            Write-Warn "$funcName not found after loading engine."
        }

        Write-Good "$engName complete."
    }
    catch {
        Write-Fail "$engName failed: $($_.Exception.Message)"
    }
}

# =====================================================
# Step 7 — Report
# =====================================================

Write-Step 7 "Summary"

if ($DryRun) {
    Write-Info "Dry run complete. No changes were applied."
    Write-Info "Remove --DryRun to apply for real."
}
else {
    # Run postcheck (if available in bundle)
    $postcheckPath = Join-Path $engineDir "postcheck.ps1"
    if (Test-Path $postcheckPath) {
        try {
            . $postcheckPath
            Invoke-Postcheck
        }
        catch {}
    }

    Write-Good "Bundle applied successfully."
    Write-Info "A rollback snapshot was saved to your reports/ directory."
    Write-Info "To undo: pwsh main.ps1 --rollback"
}

# Cleanup
Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║           ArcOS Wizard complete.            ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
