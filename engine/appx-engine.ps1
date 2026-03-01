function Invoke-AppxEngine {

    Write-ArcLog "Starting aggressive AppX rationalization."

    # =====================================================
    # CORE PROTECTED PACKAGES (DO NOT TOUCH)
    # =====================================================

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
        "Microsoft.AccountsControl",
        "Microsoft.DesktopAppInstaller",
        "Microsoft.Windows.CloudExperienceHost",
        "Microsoft.Win32WebViewHost"
    )

    # =====================================================
    # SAFE REMOVAL LIST (Consumer Layer Only)
    # =====================================================

    $Removable = @(
        "Microsoft.BingNews",
        "Microsoft.BingWeather",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.People",
        "Microsoft.PowerAutomateDesktop",
        "Microsoft.Todos",
        "Microsoft.YourPhone",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo",
        "Microsoft.LinkedIn",
        "Microsoft.XboxApp",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.XboxIdentityProvider"
    )

    # =====================================================
    # Remove Provisioned Packages
    # =====================================================

    foreach ($pkg in Get-AppxProvisionedPackage -Online) {

        if ($Protected -contains $pkg.DisplayName) {
            Write-ArcLog "Protected (skipping): $($pkg.DisplayName)"
            continue
        }

        if ($Removable -contains $pkg.DisplayName) {

            try {
                Remove-AppxProvisionedPackage `
                    -Online `
                    -PackageName $pkg.PackageName `
                    -ErrorAction SilentlyContinue | Out-Null

                Write-ArcLog "Removed provisioned: $($pkg.DisplayName)"
            }
            catch {
                Write-ArcLog "Provisioned removal failed: $($pkg.DisplayName)" "WARN"
            }
        }
    }

    # =====================================================
    # Remove Installed Packages
    # =====================================================

    foreach ($app in Get-AppxPackage -AllUsers) {

        if ($Protected -contains $app.Name) {
            continue
        }

        if ($Removable -contains $app.Name) {

            try {
                Remove-AppxPackage `
                    -Package $app.PackageFullName `
                    -AllUsers `
                    -ErrorAction SilentlyContinue

                Write-ArcLog "Removed installed: $($app.Name)"
            }
            catch {
                Write-ArcLog "Installed removal failed: $($app.Name)" "WARN"
            }
        }
    }

    Write-ArcLog "Consumer AppX removal complete."

    # =====================================================
    # Disable Xbox Services (Safer than Removing Core Packages)
    # =====================================================

    $XboxServices = @(
        "XblAuthManager",
        "XblGameSave",
        "XboxNetApiSvc",
        "XboxGipSvc"
    )

    foreach ($svc in $XboxServices) {
        try {
            Stop-Service $svc -ErrorAction SilentlyContinue
            Set-Service $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-ArcLog "Disabled service: $svc"
        }
        catch {}
    }

    # =====================================================
    # Edge – Disable Instead of Breaking Servicing
    # =====================================================

    $edgePolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

    if (-not (Test-Path $edgePolicy)) {
        New-Item -Path $edgePolicy -Force | Out-Null
    }

    Set-ItemProperty -Path $edgePolicy -Name "StartupBoostEnabled" -Type DWord -Value 0
    Set-ItemProperty -Path $edgePolicy -Name "BackgroundModeEnabled" -Type DWord -Value 0

    Write-ArcLog "Edge background behavior disabled."

    # =====================================================
    # Install Waterfox via Winget (Correct ID)
    # =====================================================

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            Start-Process `
                -FilePath "winget" `
                -ArgumentList "install WaterfoxLtd.Waterfox -e --silent --accept-package-agreements --accept-source-agreements" `
                -Wait `
                -NoNewWindow

            Write-ArcLog "Waterfox installation attempted."
        }
        catch {
            Write-ArcLog "Waterfox install failed." "WARN"
        }
    }
    else {
        Write-ArcLog "winget not available." "WARN"
    }

    Write-ArcLog "AppX engine complete."
}