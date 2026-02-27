if (-not $Config.RemoveAppx) { return }

Write-Host "Removing selected AppX packages..."

$AppsToRemove = @(
    "*Xbox*",
    "*Bing*",
    "*ZuneMusic*",
    "*GetHelp*"
)

foreach ($App in $AppsToRemove) {
    Get-AppxPackage $App -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
}