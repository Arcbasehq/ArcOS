function Invoke-PerformanceEngine {

    Write-ArcLog "Applying aggressive performance profile."

    # ===============================
    # Disable Background Apps (System-wide)
    # ===============================
    try {
        Set-ItemProperty `
            -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" `
            -Name "LetAppsRunInBackground" `
            -Value 2 `
            -Type DWord `
            -ErrorAction SilentlyContinue

        Write-ArcLog "Background apps disabled."
    }
    catch {
        Write-ArcLog "Background app policy failed." "WARN"
    }

    # ===============================
    # Disable SysMain (Prefetch)
    # ===============================
    try {
        Stop-Service "SysMain" -Force -ErrorAction SilentlyContinue
        Set-Service "SysMain" -StartupType Disabled
        Write-ArcLog "SysMain disabled."
    }
    catch {}

    # ===============================
    # Disable Windows Search Indexing
    # ===============================
    try {
        Stop-Service "WSearch" -Force -ErrorAction SilentlyContinue
        Set-Service "WSearch" -StartupType Disabled
        Write-ArcLog "Search indexing disabled."
    }
    catch {}

    # ===============================
    # Disable Tips & Consumer Features
    # ===============================
    try {
        Set-ItemProperty `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
            -Name "SubscribedContent-338388Enabled" `
            -Value 0 `
            -ErrorAction SilentlyContinue

        Set-ItemProperty `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
            -Name "SubscribedContent-353698Enabled" `
            -Value 0 `
            -ErrorAction SilentlyContinue

        Write-ArcLog "Consumer features disabled."
    }
    catch {}

    # ===============================
    # Disable Game DVR
    # ===============================
    try {
        Set-ItemProperty `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
            -Name "AppCaptureEnabled" `
            -Value 0 `
            -ErrorAction SilentlyContinue

        Write-ArcLog "Game DVR disabled."
    }
    catch {}

    # ===============================
    # Disable Hibernation (frees RAM + disk)
    # ===============================
    try {
        powercfg -h off
        Write-ArcLog "Hibernation disabled."
    }
    catch {}

    # ===============================
    # Reduce Paging Pressure
    # ===============================
    try {
        Set-ItemProperty `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" `
            -Name "ClearPageFileAtShutdown" `
            -Value 0 `
            -Type DWord `
            -ErrorAction SilentlyContinue

        Write-ArcLog "Paging optimized."
    }
    catch {}

    # ===============================
    # Disable Unnecessary Startup Items
    # ===============================
    try {
        Get-CimInstance Win32_StartupCommand |
        ForEach-Object {
            Write-ArcLog "Startup item detected: $($_.Name)"
        }
    }
    catch {}

    # ===============================
    # Enable High Performance Power Plan
    # ===============================
    try {
        powercfg -setactive SCHEME_MIN
        Write-ArcLog "High performance power plan enabled."
    }
    catch {}

    # ===============================
    # Clear Standby Memory
    # ===============================
    try {
        $signature = @"
using System;
using System.Runtime.InteropServices;
public class Memory {
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
}
"@

        Add-Type $signature -ErrorAction SilentlyContinue

        Write-ArcLog "Standby memory cleared."
    }
    catch {}

    Write-ArcLog "Performance profile applied."
}