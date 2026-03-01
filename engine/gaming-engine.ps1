function Invoke-GamingEngine {
    param (
        [object]$Config
    )

    Write-ArcLog "Applying gaming optimizations."

    function Initialize-RegPath ([string]$Path) {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
    }

    # =====================================================
    # Enable Game Mode
    # =====================================================

    try {
        $GameMode = "HKCU:\Software\Microsoft\GameBar"
        Initialize-RegPath $GameMode
        Set-ItemProperty -Path $GameMode -Name "AllowAutoGameMode" -Type DWord -Value 1
        Set-ItemProperty -Path $GameMode -Name "AutoGameModeEnabled" -Type DWord -Value 1
        Write-ArcLog "Game Mode enabled."
    }
    catch {}

    # =====================================================
    # Disable Xbox Game Bar (policy + user registry)
    # =====================================================

    try {
        $GameBarPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
        Initialize-RegPath $GameBarPolicy
        Set-ItemProperty -Path $GameBarPolicy -Name "AllowGameDVR" -Type DWord -Value 0

        $GameBar = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
        Initialize-RegPath $GameBar
        Set-ItemProperty -Path $GameBar -Name "AppCaptureEnabled"    -Type DWord -Value 0
        Set-ItemProperty -Path $GameBar -Name "GameDVR_Enabled"      -Type DWord -Value 0

        Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled"                    -Type DWord -Value 0 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode"             -Type DWord -Value 2 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode"   -Type DWord -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Type DWord -Value 1 -ErrorAction SilentlyContinue

        Write-ArcLog "Xbox Game Bar and Game DVR disabled."
    }
    catch { Write-ArcLog "Game Bar disable failed." "WARN" }

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
    # Disable Fullscreen Optimizations Globally
    # (workaround for games that benefit from exclusive FS)
    # =====================================================

    try {
        $FSO = "HKCU:\System\GameConfigStore"
        Initialize-RegPath $FSO
        Set-ItemProperty -Path $FSO -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 2
        Write-ArcLog "Fullscreen optimizations globally disabled."
    }
    catch {}

    # =====================================================
    # CPU Scheduling — Favor foreground / short quanta
    # =====================================================

    try {
        $Priority = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
        Set-ItemProperty -Path $Priority -Name "Win32PrioritySeparation" -Type DWord -Value 0x26
        Write-ArcLog "CPU scheduler set to favor foreground apps (0x26)."
    }
    catch {}

    # =====================================================
    # GPU Task Scheduling Profile
    # =====================================================

    try {
        $GamesProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        Initialize-RegPath $GamesProfile
        Set-ItemProperty -Path $GamesProfile -Name "Affinity"            -Type DWord  -Value 0
        Set-ItemProperty -Path $GamesProfile -Name "Background Only"     -Type String -Value "False"
        Set-ItemProperty -Path $GamesProfile -Name "Clock Rate"          -Type DWord  -Value 10000
        Set-ItemProperty -Path $GamesProfile -Name "GPU Priority"        -Type DWord  -Value 8
        Set-ItemProperty -Path $GamesProfile -Name "Priority"            -Type DWord  -Value 6
        Set-ItemProperty -Path $GamesProfile -Name "Scheduling Category" -Type String -Value "High"
        Set-ItemProperty -Path $GamesProfile -Name "SFIO Priority"       -Type String -Value "High"
        Write-ArcLog "GPU task scheduling profile (High priority) applied."
    }
    catch {}

    # =====================================================
    # Disable Power Throttling (prevents CPU clock from
    # being throttled on background tasks near games)
    # =====================================================

    try {
        $PowerThrottle = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
        Initialize-RegPath $PowerThrottle
        Set-ItemProperty -Path $PowerThrottle -Name "PowerThrottlingOff" -Type DWord -Value 1
        Write-ArcLog "Power throttling disabled."
    }
    catch {}

    # =====================================================
    # Disable Mouse Enhance Pointer Precision (raw input)
    # =====================================================

    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed"      -Type String -Value "0" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Type String -Value "0" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Type String -Value "0" -ErrorAction SilentlyContinue
        Write-ArcLog "Enhance Pointer Precision disabled (raw mouse input)."
    }
    catch {}

    Write-ArcLog "Gaming engine complete."
}
