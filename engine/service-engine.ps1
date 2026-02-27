function Invoke-ServiceEngine {

    Write-ArcLog "Starting service optimization."

    # Services safe to disable on most systems
    $DisableList = @(
        "DiagTrack",                # Connected User Experience
        "dmwappushservice",         # WAP Push
        "MapsBroker",
        "RetailDemo",
        "WMPNetworkSvc",
        "XboxGipSvc",
        "XblAuthManager",
        "XblGameSave",
        "XboxNetApiSvc",
        "Fax",
        "lfsvc",                    # Geolocation
        "SharedAccess",             # Internet Connection Sharing
        "WerSvc",                   # Windows Error Reporting
        "RemoteRegistry"
    )

    foreach ($svc in $DisableList) {
        try {
            $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($service) {
                Stop-Service $svc -Force -ErrorAction SilentlyContinue
                Set-Service $svc -StartupType Disabled
                Write-ArcLog "Disabled service: $svc"
            }
        }
        catch {
            Write-ArcLog "Failed disabling: $svc" "WARN"
        }
    }

    # Convert non-critical services to Manual
    $ManualList = @(
        "SysMain",
        "PrintSpooler",
        "TabletInputService",
        "WSearch",
        "WbioSrvc"
    )

    foreach ($svc in $ManualList) {
        try {
            $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($service) {
                Set-Service $svc -StartupType Manual
                Write-ArcLog "Set to Manual: $svc"
            }
        }
        catch {
            Write-ArcLog "Failed setting Manual: $svc" "WARN"
        }
    }

    # Report current service count
    $RunningCount = (Get-Service | Where-Object {$_.Status -eq "Running"}).Count
    $TotalCount   = (Get-Service).Count

    Write-ArcLog "Total services installed: $TotalCount"
    Write-ArcLog "Services currently running: $RunningCount"

    Write-ArcLog "Service optimization complete."
}