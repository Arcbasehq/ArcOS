Write-ArcLog "Smart service optimization..."

$ServicesToTune = @(
    "DiagTrack",
    "dmwappushservice"
)

foreach ($ServiceName in $ServicesToTune) {

    $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    if ($Service) {

        Save-State "SERVICE::$ServiceName" $Service.StartType

        if ($Service.Status -ne "Stopped") {
            Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
        }

        Set-Service $ServiceName -StartupType Disabled
        Write-ArcLog "Service disabled: $ServiceName"
    }
}