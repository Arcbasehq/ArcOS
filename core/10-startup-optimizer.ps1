Write-ArcLog "Running Startup Optimizer..."

$StartupPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
)

$Targets = @(
    "Microsoft Teams",
    "OneDrive",
    "Copilot",
    "Xbox"
)

foreach ($Path in $StartupPaths) {

    if (-not (Test-Path $Path)) { continue }

    $Items = Get-ItemProperty -Path $Path

    foreach ($Target in $Targets) {

        if ($Items.PSObject.Properties.Name -contains $Target) {

            $Value = (Get-ItemProperty -Path $Path -Name $Target).$Target
            Save-State "REG::$Path|$Target" $Value

            Remove-ItemProperty -Path $Path -Name $Target -ErrorAction SilentlyContinue
            Write-ArcLog "Disabled startup: $Target"
        }
    }
}