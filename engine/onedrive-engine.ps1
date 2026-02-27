function Invoke-OneDriveEngine {

    Write-ArcLog "Starting OneDrive removal process."

    try {
        # Kill running instances
        Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force

        # Uninstall OneDrive (System32 location)
        $system32 = "$env:SystemRoot\System32\OneDriveSetup.exe"
        $syswow64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"

        if (Test-Path $system32) {
            Start-Process $system32 "/uninstall" -NoNewWindow -Wait
        }

        if (Test-Path $syswow64) {
            Start-Process $syswow64 "/uninstall" -NoNewWindow -Wait
        }

        Write-ArcLog "OneDrive uninstall command executed."
    }
    catch {
        Write-ArcLog "OneDrive uninstall failed: $_" "WARN"
    }

    try {
        # Remove leftover folders
        $paths = @(
            "$env:UserProfile\OneDrive",
            "$env:LocalAppData\Microsoft\OneDrive",
            "$env:ProgramData\Microsoft OneDrive",
            "C:\OneDriveTemp"
        )

        foreach ($path in $paths) {
            if (Test-Path $path) {
                Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        Write-ArcLog "OneDrive residual folders removed."
    }
    catch {
        Write-ArcLog "OneDrive cleanup failed: $_" "WARN"
    }

    try {
        # Disable OneDrive via Group Policy registry
        $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"

        if (-not (Test-Path $policyPath)) {
            New-Item -Path $policyPath -Force | Out-Null
        }

        Set-ItemProperty -Path $policyPath `
            -Name "DisableFileSyncNGSC" `
            -Type DWord `
            -Value 1

        Write-ArcLog "OneDrive disabled via policy."
    }
    catch {
        Write-ArcLog "Failed to apply OneDrive policy: $_" "ERROR"
    }

    Write-ArcLog "OneDrive engine complete."
}