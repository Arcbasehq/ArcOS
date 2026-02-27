function Initialize-Rollback {

    Write-ArcLog "Initializing rollback snapshot."

    # Get project root (one level above /engine)
    $ProjectRoot = Split-Path $PSScriptRoot -Parent

    # Build reports path cleanly
    $ReportsPath = Join-Path $ProjectRoot "reports"

    # Ensure directory exists (even if you think it does)
    if (-not (Test-Path $ReportsPath)) {
        New-Item -Path $ReportsPath -ItemType Directory -Force | Out-Null
    }

    # Build rollback file path
    $RollbackPath = Join-Path $ReportsPath "rollback.json"

    # Snapshot data
    $Snapshot = @{
        Timestamp = Get-Date
        Services  = Get-Service | Select-Object Name, Status, StartType
        Tasks     = Get-ScheduledTask | Select-Object TaskName, TaskPath, State
    }

    # Write file
    $Snapshot | ConvertTo-Json -Depth 5 | Set-Content -Path $RollbackPath -Encoding UTF8

    Write-ArcLog "Rollback snapshot created at $RollbackPath."
}