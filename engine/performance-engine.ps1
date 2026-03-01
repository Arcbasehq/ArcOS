function Invoke-PerformanceEngine {
    param (
        [object]$Config
    )

    Write-ArcLog "Applying performance optimizations."

    # =====================================================
    # Helper: ensure registry path exists
    # =====================================================

    function Initialize-RegPath ([string]$Path) {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
    }

    # =====================================================
    # Background UWP Apps Policy
    # =====================================================

    try {
        $AppPrivacy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
        Initialize-RegPath $AppPrivacy
        Set-ItemProperty -Path $AppPrivacy -Name "LetAppsRunInBackground" -Type DWord -Value 2
        Write-ArcLog "Background UWP apps disabled."
    }
    catch { Write-ArcLog "Background app policy failed." "WARN" }

    # =====================================================
    # Game DVR Policy
    # =====================================================

    try {
        $GameDVRPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
        Initialize-RegPath $GameDVRPolicy
        Set-ItemProperty -Path $GameDVRPolicy -Name "AllowGameDVR" -Type DWord -Value 0
        Write-ArcLog "Game DVR policy disabled."
    }
    catch {}

    # =====================================================
    # SysMain / Superfetch
    # =====================================================

    if (-not $Config -or $Config.disableSuperfetch -ne $false) {
        try {
            Stop-Service SysMain -Force -ErrorAction SilentlyContinue
            Set-Service  SysMain -StartupType Disabled -ErrorAction SilentlyContinue
            Write-ArcLog "SysMain (Superfetch) disabled."
        }
        catch {}
    }

    # =====================================================
    # Windows Search Indexing
    # =====================================================

    if (-not $Config -or $Config.disableIndexing -ne $false) {
        try {
            Stop-Service WSearch -Force -ErrorAction SilentlyContinue
            Set-Service  WSearch -StartupType Disabled -ErrorAction SilentlyContinue
            Write-ArcLog "Windows Search indexing disabled."
        }
        catch {}
    }

    # =====================================================
    # Delivery Optimization
    # =====================================================

    try {
        Stop-Service DoSvc -Force -ErrorAction SilentlyContinue
        Set-Service  DoSvc -StartupType Manual -ErrorAction SilentlyContinue
        Write-ArcLog "Delivery Optimization set to manual."
    }
    catch {}

    # =====================================================
    # Hibernation (frees pagefile.sys space)
    # =====================================================

    try {
        powercfg -h off 2>$null
        Write-ArcLog "Hibernation disabled."
    }
    catch {}

    # =====================================================
    # High Performance Power Plan
    # =====================================================

    if (-not $Config -or $Config.optimizePowerSettings -ne $false) {
        try {
            powercfg -setactive SCHEME_MIN 2>$null
            Write-ArcLog "High performance power plan activated."
        }
        catch {}
    }

    # =====================================================
    # CPU Priority — Foreground App Boost
    # =====================================================

    try {
        $PriorityControl = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
        Initialize-RegPath $PriorityControl
        Set-ItemProperty -Path $PriorityControl -Name "Win32PrioritySeparation" -Type DWord -Value 38
        Write-ArcLog "CPU foreground priority boost applied (Win32PrioritySeparation = 38)."
    }
    catch {}

    # =====================================================
    # Power Throttling Disable
    # =====================================================

    try {
        $PowerThrottle = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
        Initialize-RegPath $PowerThrottle
        Set-ItemProperty -Path $PowerThrottle -Name "PowerThrottlingOff" -Type DWord -Value 1
        Write-ArcLog "Power throttling disabled."
    }
    catch {}

    # =====================================================
    # Memory Management
    # =====================================================

    try {
        $MM = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        Set-ItemProperty -Path $MM -Name "ClearPageFileAtShutdown" -Type DWord -Value 0
        Set-ItemProperty -Path $MM -Name "LargeSystemCache"        -Type DWord -Value 0
        Set-ItemProperty -Path $MM -Name "DisablePagingExecutive"  -Type DWord -Value 1
        Write-ArcLog "Memory management optimized."
    }
    catch {}

    # =====================================================
    # Disable Memory Compression
    # =====================================================

    try {
        Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
        Write-ArcLog "Memory compression disabled."
    }
    catch {}

    # =====================================================
    # NTFS Last Access Timestamp (reduces I/O)
    # =====================================================

    try {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
            -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 1
        Write-ArcLog "NTFS last access timestamp disabled."
    }
    catch {}

    # =====================================================
    # Fast Startup Disable (ensures full shutdown)
    # =====================================================

    try {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" `
            -Name "HiberbootEnabled" -Type DWord -Value 0
        Write-ArcLog "Fast startup disabled."
    }
    catch {}

    # =====================================================
    # Hardware Accelerated GPU Scheduling (HAGS)
    # =====================================================

    try {
        $GfxDrivers = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        Initialize-RegPath $GfxDrivers
        Set-ItemProperty -Path $GfxDrivers -Name "HwSchMode" -Type DWord -Value 2
        Write-ArcLog "Hardware Accelerated GPU Scheduling (HAGS) enabled."
    }
    catch {}

    # =====================================================
    # Multimedia System Profile (Network + CPU)
    # =====================================================

    try {
        $MP = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-ItemProperty -Path $MP -Name "NetworkThrottlingIndex" -Type DWord -Value 0xFFFFFFFF
        Set-ItemProperty -Path $MP -Name "SystemResponsiveness"   -Type DWord -Value 0
        Write-ArcLog "Multimedia system profile optimized."
    }
    catch {}

    # =====================================================
    # Gaming Tasks Profile (latency tuning)
    # =====================================================

    try {
        $GamesProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        Initialize-RegPath $GamesProfile
        Set-ItemProperty -Path $GamesProfile -Name "Affinity"             -Type DWord  -Value 0
        Set-ItemProperty -Path $GamesProfile -Name "Background Only"      -Type String -Value "False"
        Set-ItemProperty -Path $GamesProfile -Name "Clock Rate"           -Type DWord  -Value 10000
        Set-ItemProperty -Path $GamesProfile -Name "GPU Priority"         -Type DWord  -Value 8
        Set-ItemProperty -Path $GamesProfile -Name "Priority"             -Type DWord  -Value 6
        Set-ItemProperty -Path $GamesProfile -Name "Scheduling Category"  -Type String -Value "High"
        Set-ItemProperty -Path $GamesProfile -Name "SFIO Priority"        -Type String -Value "High"
        Write-ArcLog "Gaming task scheduling profile applied."
    }
    catch {}

    # =====================================================
    # SvcHost Split Threshold (reduces svchost.exe count)
    # =====================================================

    try {
        $ram = (Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize * 1KB
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" `
            -Name "SvcHostSplitThresholdInKB" -Type DWord -Value ([math]::Round($ram))
        Write-ArcLog "SvcHost split threshold set to installed RAM size."
    }
    catch {}

    # =====================================================
    # Disable Consumer Experience Content
    # =====================================================

    try {
        $CDM = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        $cdmKeys = @(
            "SubscribedContent-338388Enabled",
            "SubscribedContent-338389Enabled",
            "SubscribedContent-353698Enabled",
            "SubscribedContent-310093Enabled",
            "SilentInstalledAppsEnabled",
            "SystemPaneSuggestionsEnabled",
            "PreInstalledAppsEnabled",
            "OemPreInstalledAppsEnabled"
        )
        foreach ($key in $cdmKeys) {
            Set-ItemProperty -Path $CDM -Name $key -Value 0 -ErrorAction SilentlyContinue
        }
        Write-ArcLog "Consumer experience content disabled."
    }
    catch {}

    Write-ArcLog "Performance engine complete."
}