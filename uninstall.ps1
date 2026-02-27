# ===================================
# ArcOS State-Aware Uninstaller
# ===================================

$StatePath = "$PSScriptRoot\state.json"

if (-not (Test-Path $StatePath)) {
    Write-Host "No state file found. Nothing to restore."
    exit
}

$State = Get-Content $StatePath | ConvertFrom-Json

Write-Host "Restoring saved system state..."

foreach ($Property in $State.PSObject.Properties) {

    $Key = $Property.Name
    $Value = $Property.Value

    # Registry restore
    if ($Key -like "REG::*") {

        $Parts = $Key.Replace("REG::","").Split("|")
        $RegPath = $Parts[0]
        $RegName = $Parts[1]

        try {
            Set-ItemProperty -Path $RegPath -Name $RegName -Value $Value -ErrorAction Stop
            Write-Host "Restored registry: $RegPath -> $RegName"
        }
        catch {
            Write-Host "Failed to restore registry: $RegPath"
        }
    }

    # Service restore
    elseif ($Key -like "SERVICE::*") {

        $ServiceName = $Key.Replace("SERVICE::","")

        try {
            Set-Service -Name $ServiceName -StartupType $Value -ErrorAction Stop
            Write-Host "Restored service: $ServiceName"
        }
        catch {
            Write-Host "Failed to restore service: $ServiceName"
        }
    }

    # Power plan restore
    elseif ($Key -eq "POWERPLAN") {

        try {
            powercfg -setactive $Value
            Write-Host "Restored power plan."
        }
        catch {
            Write-Host "Failed to restore power plan."
        }
    }
}

Write-Host "Removing ArcOS directory..."
Remove-Item 'C:\ArcOS' -Recurse -Force -ErrorAction SilentlyContinue

Remove-Item $StatePath -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "ArcOS state restored successfully."