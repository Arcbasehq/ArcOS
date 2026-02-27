if (-not $Config.OptimizeServices) { return }

Write-Host "Optimizing services..."

$ServicesToDisable = @(
    "DiagTrack",
    "dmwappushservice"
)

foreach ($Service in $ServicesToDisable) {
    if (Get-Service $Service -ErrorAction SilentlyContinue) {
        Stop-Service $Service -Force -ErrorAction SilentlyContinue
        Set-Service $Service -StartupType Disabled
    }
}