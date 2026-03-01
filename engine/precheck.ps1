function Invoke-Precheck {

    Write-ArcLog "Running pre-deployment validation."

    # =====================================================
    # Windows Build Check
    # =====================================================

    $os = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int]$os.CurrentBuild

    if ($build -lt 19041) {
        throw "Unsupported Windows build: $build. ArcOS requires Windows 10 20H1 (19041) or newer."
    }

    Write-ArcLog "Windows build $build validated."

    # =====================================================
    # Free Disk Space Check (min 10 GB)
    # =====================================================

    try {
        $sysDrive = $env:SystemDrive
        $disk = Get-PSDrive -Name ($sysDrive.TrimEnd(':')) -ErrorAction SilentlyContinue
        if ($disk) {
            $freeGB = [math]::Round($disk.Free / 1GB, 1)
            if ($freeGB -lt 10) {
                throw "Insufficient disk space: $freeGB GB free. At least 10 GB required."
            }
            Write-ArcLog "Disk space OK: $freeGB GB free on $sysDrive"
        }
    }
    catch {
        if ($_.Exception.Message -like "*Insufficient*") { throw }
        Write-ArcLog "Could not check disk space." "WARN"
    }

    # =====================================================
    # RAM Check (min 4 GB)
    # =====================================================

    try {
        $ramGB = [math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1MB, 1)
        if ($ramGB -lt 4) {
            Write-ArcLog "Low RAM detected: $ramGB GB. Some optimizations may have limited effect." "WARN"
        }
        else {
            Write-ArcLog "RAM OK: $ramGB GB installed."
        }
    }
    catch {
        Write-ArcLog "Could not check RAM." "WARN"
    }

    # =====================================================
    # Secure Boot + TPM Notice
    # =====================================================

    try {
        $sb = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
        Write-ArcLog "Secure Boot: $( if ($sb) { 'Enabled' } else { 'Disabled' } )"
    }
    catch {
        Write-ArcLog "Secure Boot status unknown (BIOS mode or not supported)." "WARN"
    }

    # =====================================================
    # Baseline Benchmark Snapshot
    # =====================================================

    try {
        $ProjectRoot = Split-Path $PSScriptRoot -Parent
        $reportsPath = Join-Path $ProjectRoot "reports"
        $baselinePath = Join-Path $reportsPath "baseline.json"

        if (-not (Test-Path $reportsPath)) {
            New-Item -ItemType Directory -Path $reportsPath -Force | Out-Null
        }

        $osInfo = Get-CimInstance Win32_OperatingSystem

        $baseline = @{
            Timestamp       = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            WindowsBuild    = $build
            ServicesRunning = (Get-Service | Where-Object { $_.Status -eq "Running" }).Count
            ServicesTotal   = (Get-Service).Count
            TasksEnabled    = (Get-ScheduledTask | Where-Object { $_.State -ne "Disabled" }).Count
            TasksTotal      = (Get-ScheduledTask).Count
            FreeRAM_MB      = [math]::Round($osInfo.FreePhysicalMemory / 1KB)
            TotalRAM_MB     = [math]::Round($osInfo.TotalVisibleMemorySize / 1KB)
            FreeRAM_Percent = [math]::Round(($osInfo.FreePhysicalMemory / $osInfo.TotalVisibleMemorySize) * 100, 1)
        }

        $baseline | ConvertTo-Json | Set-Content -Path $baselinePath -Encoding UTF8
        Write-ArcLog "Baseline snapshot saved: $($baseline.ServicesRunning) running services, $([math]::Round($baseline.FreeRAM_MB))MB free RAM"
    }
    catch {
        Write-ArcLog "Could not save baseline snapshot: $($_.Exception.Message)" "WARN"
    }

    Write-ArcLog "Pre-deployment validation complete."
}