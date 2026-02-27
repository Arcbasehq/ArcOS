$Script:RollbackPath = Join-Path $PSScriptRoot '..\reports\rollback.json'

function Initialize-Rollback {

    Write-ArcLog "Initializing rollback snapshot."

    $services = Get-Service | Select-Object Name, StartType

    $snapshot = @{
        Services = $services
    }

    $snapshot | ConvertTo-Json -Depth 5 |
        Set-Content -Path $Script:RollbackPath
}