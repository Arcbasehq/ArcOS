if (-not $Config.DisableTasks) { return }

Write-Host "Disabling telemetry scheduled tasks..."

$Tasks = @(
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
)

foreach ($Task in $Tasks) {
    Disable-ScheduledTask -TaskPath (Split-Path $Task -Parent) `
                           -TaskName (Split-Path $Task -Leaf) `
                           -ErrorAction SilentlyContinue
}