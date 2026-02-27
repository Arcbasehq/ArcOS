function Invoke-AppxEngine {

    Write-ArcLog "Starting aggressive AppX removal."

    # ===============================
    # Protected Core Components
    # ===============================

    $Protected = @(
        "Microsoft.NET.Native.Framework",
        "Microsoft.NET.Native.Runtime",
        "Microsoft.VCLibs",
        "Microsoft.UI.Xaml",
        "Microsoft.WindowsStore",
        "Microsoft.StorePurchaseApp",
        "Microsoft.Windows.ShellExperienceHost",
        "Microsoft.Windows.StartMenuExperienceHost",
        "Microsoft.AAD.BrokerPlugin",
        "Microsoft.AccountsControl"
    )

    # ===============================
    # Remove Provisioned Packages
    # ===============================

    $Provisioned = Get-AppxProvisionedPackage -Online

    foreach ($pkg in $Provisioned) {

        $name = $pkg.DisplayName

        if ($Protected -contains $name) { continue }

        try {
            Remove-AppxProvisionedPackage `
                -Online `
                -PackageName $pkg.PackageName `
                -ErrorAction SilentlyContinue | Out-Null

            Write-ArcLog "Removed provisioned: $name"
        }
        catch {
            Write-ArcLog "Provisioned removal failed: $name" "WARN"
        }
    }

    # ===============================
    # Remove Installed Packages
    # ===============================

    $Installed = Get-AppxPackage -AllUsers

    foreach ($app in $Installed) {

        $name = $app.Name

        if ($Protected -contains $name) { continue }

        try {
            Remove-AppxPackage `
                -Package $app.PackageFullName `
                -AllUsers `
                -ErrorAction SilentlyContinue

            Write-ArcLog "Removed installed: $name"
        }
        catch {
            Write-ArcLog "Installed removal failed: $name" "WARN"
        }
    }

    Write-ArcLog "Store apps removal complete."

    # ===============================
    # Remove Microsoft Edge
    # ===============================

    $EdgePath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application"

    if (Test-Path $EdgePath) {
        $Installer = Get-ChildItem `
            "$EdgePath\*\Installer\setup.exe" `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($Installer) {
            try {
                Start-Process `
                    -FilePath $Installer.FullName `
                    -ArgumentList "--uninstall --system-level --force-uninstall --verbose-logging" `
                    -Wait `
                    -NoNewWindow

                Write-ArcLog "Edge uninstall attempted."
            }
            catch {
                Write-ArcLog "Edge uninstall failed." "WARN"
            }
        }
    }

    # ===============================
    # Remove WebView2
    # ===============================

    $WebView = Get-ItemProperty `
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*WebView2*" }

    foreach ($entry in $WebView) {
        try {
            Start-Process `
                -FilePath "msiexec.exe" `
                -ArgumentList "/x $($entry.PSChildName) /quiet /norestart" `
                -Wait `
                -NoNewWindow

            Write-ArcLog "Removed WebView2."
        }
        catch {
            Write-ArcLog "WebView2 removal failed." "WARN"
        }
    }

    # ===============================
    # Install Waterfox
    # ===============================

    $winget = Get-Command winget -ErrorAction SilentlyContinue

    if ($winget) {
        try {
            Start-Process `
                -FilePath "winget" `
                -ArgumentList "install --id Waterfox.Waterfox -e --silent --accept-package-agreements --accept-source-agreements" `
                -Wait `
                -NoNewWindow

            Write-ArcLog "Waterfox installed."
        }
        catch {
            Write-ArcLog "Waterfox install failed." "ERROR"
        }
    }
    else {
        Write-ArcLog "winget not found. Skipping Waterfox install." "ERROR"
    }

    Write-ArcLog "AppX engine complete."
}