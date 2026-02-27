if (-not $Config.RemoveAppx) { return }

Write-ArcLog "Targeted stock app removal starting..."

# Apps safe to remove
$AppsToRemove = @(
    "Microsoft.WindowsAlarms",              # Clock
    "Microsoft.WindowsCalendar",            # Calendar (legacy)
    "Microsoft.OutlookForWindows",          # New Outlook (if installed)
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.People",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.BingWeather",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.549981C3F5F10",              # Cortana
    "MicrosoftWindows.Client.WebExperience", # Widgets
    "MicrosoftTeams",
    "Clipchamp.Clipchamp"
)

foreach ($App in $AppsToRemove) {

    $Installed = Get-AppxPackage -AllUsers | Where-Object { $_.Name -eq $App }

    foreach ($Package in $Installed) {

        try {
            Save-State "APPX::$($Package.Name)" $Package.PackageFullName
            Remove-AppxPackage -Package $Package.PackageFullName -AllUsers -ErrorAction Stop
            Write-ArcLog "Removed AppX: $($Package.Name)"
        }
        catch {
            Write-ArcLog "Failed removing $($Package.Name): $_" "WARN"
        }
    }

    # Remove provisioned version (so it doesn’t reinstall)
    $Provisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $App }

    foreach ($Prov in $Provisioned) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $Prov.PackageName -ErrorAction Stop
            Write-ArcLog "Removed provisioned: $App"
        }
        catch {
            Write-ArcLog "Failed removing provisioned $App" "WARN"
        }
    }
}

Write-ArcLog "Targeted stock app removal complete."