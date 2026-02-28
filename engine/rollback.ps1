function Initialize-Rollback {

    Write-ArcLog "Initializing comprehensive rollback system."

    # Get project root (one level above /engine)
    $ProjectRoot = Split-Path $PSScriptRoot -Parent

    # Build reports path cleanly
    $ReportsPath = Join-Path $ProjectRoot "reports"

    # Ensure directory exists
    if (-not (Test-Path $ReportsPath)) {
        New-Item -Path $ReportsPath -ItemType Directory -Force | Out-Null
    }

    # Build rollback file path
    $RollbackPath = Join-Path $ReportsPath "rollback-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $LatestRollbackPath = Join-Path $ReportsPath "rollback-latest.json"

    # Snapshot comprehensive system state
    $Snapshot = @{
        Timestamp        = Get-Date
        WindowsBuild     = $Global:CurrentBuild
        SystemInfo       = @{
            OSVersion       = (Get-CimInstance Win32_OperatingSystem).Caption
            Architecture     = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
            TotalRAM_GB     = [math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1MB)
            FreeRAM_GB      = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB)
        }
        Services        = Get-Service | Select-Object Name, DisplayName, Status, StartType
        ScheduledTasks   = Get-ScheduledTask | Select-Object TaskName, TaskPath, State, Enabled
        RegistryState   = @{}
        InstalledApps   = Get-AppxPackage | Select-Object Name, PackageFullName, InstallLocation
        Policies        = @{}
        PerformanceSettings = @{}
        UISettings      = @{}
        NetworkSettings = @{}
    }

    try {
        # Capture registry state for key areas
        $Snapshot.RegistryState.Telemetry = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -ErrorAction SilentlyContinue
        $Snapshot.RegistryState.Privacy = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -ErrorAction SilentlyContinue
        
        # Capture group policies
        $Snapshot.Policies.Telemetry = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ErrorAction SilentlyContinue
        
        # Capture performance settings
        $Snapshot.PerformanceSettings.VisualEffects = Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -ErrorAction SilentlyContinue
        
        # Write file
        $Snapshot | ConvertTo-Json -Depth 10 | Set-Content -Path $RollbackPath -Encoding UTF8
        $Snapshot | ConvertTo-Json -Depth 10 | Set-Content -Path $LatestRollbackPath -Encoding UTF8

        Write-ArcLog "Comprehensive rollback snapshot created at $RollbackPath"
    }
    catch {
        Write-ArcLog "Rollback initialization failed: $($_.Exception.Message)" "ERROR"
    }
}

function Apply-Rollback {
    param (
        [string]$RollbackFile = "rollback-latest.json"
    )
    
    $ProjectRoot = Split-Path $PSScriptRoot -Parent
    $ReportsPath = Join-Path $ProjectRoot "reports"
    $RollbackPath = Join-Path $ReportsPath $RollbackFile
    
    if (-not (Test-Path $RollbackPath)) {
        Write-ArcLog "Rollback file not found: $RollbackPath" "ERROR"
        return $false
    }
    
    try {
        $RollbackData = Get-Content $RollbackPath -Raw | ConvertFrom-Json
        Write-ArcLog "Starting rollback process using snapshot from $($RollbackData.Timestamp)"
        
        # Restore services
        foreach ($service in $RollbackData.Services) {
            try {
                $currentService = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
                if ($currentService) {
                    if ($currentService.Status -ne $service.Status) {
                        if ($service.Status -eq "Running") {
                            Start-Service -Name $service.Name -ErrorAction SilentlyContinue
                        } elseif ($service.Status -eq "Stopped") {
                            Stop-Service -Name $service.Name -ErrorAction SilentlyContinue
                        }
                    }
                    
                    if ($currentService.StartType -ne $service.StartType) {
                        Set-Service -Name $service.Name -StartupType $service.StartType -ErrorAction SilentlyContinue
                    }
                }
            }
            catch {
                Write-ArcLog "Failed to restore service $($service.Name): $($_.Exception.Message)" "WARN"
            }
        }
        
        # Restore scheduled tasks
        foreach ($task in $RollbackData.ScheduledTasks) {
            try {
                $currentTask = Get-ScheduledTask -TaskName $task.TaskName -ErrorAction SilentlyContinue
                if ($currentTask -and $currentTask.State -ne $task.State) {
                    if ($task.State -eq "Disabled") {
                        Disable-ScheduledTask -TaskName $task.TaskName -ErrorAction SilentlyContinue
                    } elseif ($task.State -eq "Enabled") {
                        Enable-ScheduledTask -TaskName $task.TaskName -ErrorAction SilentlyContinue
                    }
                }
            }
            catch {
                Write-ArcLog "Failed to restore task $($task.TaskName): $($_.Exception.Message)" "WARN"
            }
        }
        
        Write-ArcLog "Rollback process completed. Some changes may require manual intervention."
        return $true
    }
    catch {
        Write-ArcLog "Rollback failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}