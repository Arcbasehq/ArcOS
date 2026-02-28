<#
ArcOS Framework - Interactive CLI
#>

# Load main script functions
$scriptPath = Join-Path $PSScriptRoot "main.ps1"
if (-not (Test-Path $scriptPath)) {
    Write-Host "Main script not found!" -ForegroundColor Red
    exit 1
}

# Import the main script to access its functions
. $scriptPath

function Show-MainMenu {
    Clear-Host
    Write-Host "" 
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          ArcOS Framework - Windows Optimization Tool          ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Show system info
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $build = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
        
        Write-Host "System Information:" -ForegroundColor Green
        Write-Host "  OS: $($os.Caption)" -ForegroundColor White
        Write-Host "  Build: $build" -ForegroundColor White
        Write-Host "  RAM: $([math]::Round($os.TotalVisibleMemorySize / 1MB)) GB" -ForegroundColor White
        Write-Host ""
    }
    catch {}
    
    Write-Host "Main Menu:" -ForegroundColor Yellow
    Write-Host "  1. Run Optimization (Apply settings)" -ForegroundColor White
    Write-Host "  2. Rollback System (Restore previous state)" -ForegroundColor White
    Write-Host "  3. Edit Configuration (Customize settings)" -ForegroundColor White
    Write-Host "  4. View Reports (Check previous runs)" -ForegroundColor White
    Write-Host "  5. System Information (Detailed info)" -ForegroundColor White
    Write-Host "  6. Exit" -ForegroundColor White
    Write-Host ""
    Write-Host "Current Profile: $($Config.profile)" -ForegroundColor Magenta
    Write-Host ""
}

function Show-EditConfigMenu {
    Clear-Host
    Write-Host "" 
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                   Configuration Editor                        ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Configuration Options:" -ForegroundColor Yellow
    Write-Host "  1. Change Profile (balanced/aggressive/stable/performance)" -ForegroundColor White
    Write-Host "  2. Enable/Disable Engines" -ForegroundColor White
    Write-Host "  3. Advanced Settings" -ForegroundColor White
    Write-Host "  4. Reset to Defaults" -ForegroundColor White
    Write-Host "  5. Back to Main Menu" -ForegroundColor White
    Write-Host ""
    Write-Host "Current Configuration:" -ForegroundColor Green
    Write-Host "  Profile: $($Config.profile)" -ForegroundColor White
    Write-Host "  Auto-reboot: $($Config.advanced.autoReboot)" -ForegroundColor White
    Write-Host "  Verbose logging: $($Config.advanced.verboseLogging)" -ForegroundColor White
    Write-Host ""
}

function Edit-Profile {
    Clear-Host
    Write-Host "Current Profile: $($Config.profile)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Available Profiles:" -ForegroundColor Green
    Write-Host "  1. balanced     - Recommended for most users" -ForegroundColor White
    Write-Host "  2. aggressive   - Maximum optimizations" -ForegroundColor White
    Write-Host "  3. stable       - Conservative changes only" -ForegroundColor White
    Write-Host "  4. performance  - Focus on speed improvements" -ForegroundColor White
    Write-Host "  5. Back to Configuration Menu" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Select profile (1-5)"
    
    switch ($choice) {
        "1" { $Config.profile = "balanced" }
        "2" { $Config.profile = "aggressive" }
        "3" { $Config.profile = "stable" }
        "4" { $Config.profile = "performance" }
        "5" { return }
        default { 
            Write-Host "Invalid choice. Using current profile." -ForegroundColor Red
            Start-Sleep -Seconds 1
            return
        }
    }
    
    # Save configuration
    $Config | ConvertTo-Json -Depth 10 | Out-File $configPath
    Write-Host "Profile changed to $($Config.profile)" -ForegroundColor Green
    Start-Sleep -Seconds 2
}

function Toggle-Engines {
    Clear-Host
    Write-Host "Engine Configuration" -ForegroundColor Yellow
    Write-Host "Current status:" -ForegroundColor Green
    Write-Host ""
    
    $index = 1
    $engineMap = @{}
    
    $EngineManifest.Keys | ForEach-Object {
        $engineName = $_
        $status = if ($Config.engines.$engineName.enabled) { "ENABLED" } else { "DISABLED" }
        $statusColor = if ($Config.engines.$engineName.enabled) { "Green" } else { "Red" }
        
        Write-Host "  $index. $engineName - $status" -ForegroundColor $statusColor
        $engineMap[$index] = $engineName
        $index++
    }
    
    Write-Host "  $index. Back to Configuration Menu" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Select engine to toggle (1-$index)"
    
    if ($choice -eq $index) { return }
    
    if ($engineMap[$choice]) {
        $engineName = $engineMap[$choice]
        $Config.engines.$engineName.enabled = -not $Config.engines.$engineName.enabled
        
        # Save configuration
        $Config | ConvertTo-Json -Depth 10 | Out-File $configPath
        
        $newStatus = if ($Config.engines.$engineName.enabled) { "enabled" } else { "disabled" }
        Write-Host "$engineName $newStatus" -ForegroundColor Green
        Start-Sleep -Seconds 1
    } else {
        Write-Host "Invalid choice." -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}

function Show-Reports {
    Clear-Host
    $reportsPath = Join-Path $root "reports"
    
    if (-not (Test-Path $reportsPath)) {
        Write-Host "No reports found." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }
    
    Write-Host "Available Reports:" -ForegroundColor Yellow
    Write-Host ""
    
    $files = Get-ChildItem -Path $reportsPath -Filter "*.json" | Sort-Object LastWriteTime -Descending
    
    if ($files.Count -eq 0) {
        Write-Host "No reports found." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }
    
    $index = 1
    foreach ($file in $files) {
        Write-Host "  $index. $($file.Name) - $($file.LastWriteTime)" -ForegroundColor White
        $index++
    }
    
    Write-Host "  $index. Back to Main Menu" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Select report to view (1-$index)"
    
    if ($choice -eq $index) { return }
    
    if ($choice -ge 1 -and $choice -le $files.Count) {
        $selectedFile = $files[$choice - 1]
        $reportContent = Get-Content -Path $selectedFile.FullName -Raw | ConvertFrom-Json
        
        Clear-Host
        Write-Host "Report: $($selectedFile.Name)" -ForegroundColor Cyan
        Write-Host "Generated: $($reportContent.Timestamp)" -ForegroundColor White
        Write-Host "Profile: $($reportContent.Profile)" -ForegroundColor White
        Write-Host "Windows Build: $($reportContent.WindowsBuild)" -ForegroundColor White
        Write-Host ""
        Write-Host "Engine Execution:" -ForegroundColor Green
        
        foreach ($engine in $reportContent.Engines) {
            $statusColor = if ($engine.Status -eq "Success") { "Green" } else { "Red" }
            Write-Host "  $($engine.Engine): $($engine.Status)" -ForegroundColor $statusColor
        }
        
        Write-Host ""
        Write-Host "Press any key to return..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Show-SystemInfo {
    Clear-Host
    Write-Host "System Information" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Basic system info
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $build = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
        
        Write-Host "Operating System:" -ForegroundColor Green
        Write-Host "  Name: $($os.Caption)" -ForegroundColor White
        Write-Host "  Version: $($os.Version)" -ForegroundColor White
        Write-Host "  Build: $build" -ForegroundColor White
        Write-Host "  Architecture: $($os.OSArchitecture)" -ForegroundColor White
        Write-Host "  Install Date: $($os.InstallDate)" -ForegroundColor White
        Write-Host ""
        
        Write-Host "Hardware:" -ForegroundColor Green
        Write-Host "  CPU: $($cpu.Name)" -ForegroundColor White
        Write-Host "  Cores: $($cpu.NumberOfCores)" -ForegroundColor White
        Write-Host "  Logical Processors: $($cpu.NumberOfLogicalProcessors)" -ForegroundColor White
        Write-Host "  RAM: $([math]::Round($os.TotalVisibleMemorySize / 1GB, 2)) GB" -ForegroundColor White
        Write-Host "  Free RAM: $([math]::Round($os.FreePhysicalMemory / 1GB, 2)) GB" -ForegroundColor White
        Write-Host "  Disk (C:): $([math]::Round($disk.Size / 1GB, 2)) GB" -ForegroundColor White
        Write-Host "  Free Disk: $([math]::Round($disk.FreeSpace / 1GB, 2)) GB" -ForegroundColor White
        Write-Host ""
        
        Write-Host "System Status:" -ForegroundColor Green
        Write-Host "  Processes: $(Get-Process).Count" -ForegroundColor White
        Write-Host "  Services: $(Get-Service).Count" -ForegroundColor White
        Write-Host "  Uptime: $((Get-Date) - $os.LastBootUpTime)" -ForegroundColor White
        Write-Host ""
        
        Write-Host "Press any key to return..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
    } catch {
        Write-Host "Error gathering system information: $($_.Exception.Message)" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

# Main CLI loop
try {
    # Load configuration
    $root = Split-Path -Parent $MyInvocation.MyCommand.Path
    $configPath = Join-Path $root "config.json"
    
    if (Test-Path $configPath) {
        $Config = Get-Content $configPath -Raw | ConvertFrom-Json
    } else {
        Write-Host "Configuration file not found. Creating default..." -ForegroundColor Yellow
        # This will be created when main.ps1 runs
        $Config = @{
            version = "1.0"
            profile = "balanced"
            engines = @{}
            advanced = @{
                createRestorePoint = $true
                skipCompatibilityCheck = $false
                dryRunMode = $false
                verboseLogging = $false
                autoReboot = $true
            }
        }
    }
    
    while ($true) {
        Show-MainMenu
        $choice = Read-Host "Select option (1-6)"
        
        switch ($choice) {
            "1" {  # Run Optimization
                Write-Host "Starting ArcOS optimization..." -ForegroundColor Green
                Start-Sleep -Seconds 2
                # Call the main script
                & $scriptPath
                break
            }
            
            "2" {  # Rollback
                Clear-Host
                Write-Host "Rollback Options:" -ForegroundColor Yellow
                Write-Host "  1. Rollback to latest snapshot" -ForegroundColor White
                Write-Host "  2. Select specific snapshot" -ForegroundColor White
                Write-Host "  3. Back to Main Menu" -ForegroundColor White
                Write-Host ""
                
                $rollbackChoice = Read-Host "Select rollback option (1-3)"
                
                switch ($rollbackChoice) {
                    "1" {
                        Write-Host "Rolling back to latest snapshot..." -ForegroundColor Yellow
                        Start-Sleep -Seconds 2
                        & $scriptPath --rollback
                        break
                    }
                    
                    "2" {
                        $reportsPath = Join-Path $root "reports"
                        $files = Get-ChildItem -Path $reportsPath -Filter "rollback-*.json" | Sort-Object LastWriteTime -Descending
                        
                        if ($files.Count -eq 0) {
                            Write-Host "No rollback snapshots found." -ForegroundColor Red
                            Start-Sleep -Seconds 2
                        } else {
                            Clear-Host
                            Write-Host "Available Rollback Snapshots:" -ForegroundColor Yellow
                            Write-Host ""
                            
                            $index = 1
                            foreach ($file in $files) {
                                Write-Host "  $index. $($file.Name) - $($file.LastWriteTime)" -ForegroundColor White
                                $index++
                            }
                            
                            Write-Host "  $index. Back to Main Menu" -ForegroundColor White
                            Write-Host ""
                            
                            $snapshotChoice = Read-Host "Select snapshot (1-$index)"
                            
                            if ($snapshotChoice -ge 1 -and $snapshotChoice -le $files.Count) {
                                $selectedFile = $files[$snapshotChoice - 1].Name
                                Write-Host "Rolling back to $selectedFile..." -ForegroundColor Yellow
                                Start-Sleep -Seconds 2
                                & $scriptPath --rollback $selectedFile
                                break
                            }
                        }
                    }
                    
                    "3" { continue }
                    
                    default {
                        Write-Host "Invalid choice." -ForegroundColor Red
                        Start-Sleep -Seconds 1
                    }
                }
            }
            
            "3" {  # Edit Configuration
                while ($true) {
                    Show-EditConfigMenu
                    $configChoice = Read-Host "Select option (1-5)"
                    
                    switch ($configChoice) {
                        "1" { Edit-Profile }
                        "2" { Toggle-Engines }
                        "3" { 
                            Write-Host "Advanced settings coming soon!" -ForegroundColor Yellow
                            Start-Sleep -Seconds 1
                        }
                        "4" { 
                            Write-Host "Resetting to defaults..." -ForegroundColor Yellow
                            # Remove config file, it will be recreated on next run
                            Remove-Item $configPath -Force
                            Start-Sleep -Seconds 1
                            return
                        }
                        "5" { break }
                        default {
                            Write-Host "Invalid choice." -ForegroundColor Red
                            Start-Sleep -Seconds 1
                        }
                    }
                }
            }
            
            "4" { Show-Reports }
            
            "5" { Show-SystemInfo }
            
            "6" { 
                Write-Host "Exiting ArcOS Framework..." -ForegroundColor Yellow
                exit 0
            }
            
            default {
                Write-Host "Invalid choice. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
    
} catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}