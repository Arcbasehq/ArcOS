Write-ArcLog "Starting browser replacement process..."

# ===================================
# 1. Attempt Safe Microsoft Edge Removal
# ===================================

$EdgeBase = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application"

if (Test-Path $EdgeBase) {
    try {
        $Setup = Get-ChildItem "$EdgeBase\*\Installer\setup.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($Setup) {
            Write-ArcLog "Attempting Edge uninstall (browser only)..."
            Start-Process $Setup.FullName `
                -ArgumentList "--uninstall --system-level --force-uninstall --verbose-logging" `
                -Wait -NoNewWindow
            Write-ArcLog "Edge uninstall attempt completed."
        } else {
            Write-ArcLog "Edge setup not found. Skipping uninstall." "WARN"
        }
    } catch {
        Write-ArcLog "Edge uninstall failed: $_" "WARN"
    }
} else {
    Write-ArcLog "Edge not detected. Skipping uninstall."
}

# ===================================
# 2. Download & Install Waterfox
# ===================================

try {
    Write-ArcLog "Downloading Waterfox installer..."

    # Official installer from Waterfox site (latest stable)
    $DownloadUrl = "https://cdn1.waterfox.net/waterfox/releases/6.6.8/WINNT_x86_64/Waterfox%20Setup%206.6.8.exe"
    $InstallerPath = "$env:TEMP\waterfox_setup.exe"

    Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing

    Write-ArcLog "Installing Waterfox..."
    Start-Process $InstallerPath -ArgumentList "/S" -Wait -NoNewWindow

    Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue

    Write-ArcLog "Waterfox installed successfully."
} catch {
    Write-ArcLog "Waterfox installation failed: $_" "ERROR"
}

Write-ArcLog "Browser replacement process complete."