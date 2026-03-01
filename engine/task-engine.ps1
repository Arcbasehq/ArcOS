function Invoke-TaskEngine {
    param (
        [object]$Config
    )

    Write-ArcLog "Starting scheduled task optimization."

    $manifestPath = if ($Global:ArcManifestDir) {
        Join-Path $Global:ArcManifestDir 'tasks.json'
    }
    else {
        Join-Path $PSScriptRoot '..\manifests\tasks.json'
    }

    if (-not (Test-Path $manifestPath)) {
        Write-ArcLog "tasks.json manifest not found." "WARN"
        return
    }

    $tasks = Get-Content $manifestPath -Raw | ConvertFrom-Json

    $disabledCount = 0
    $skippedCount = 0
    $notFoundCount = 0

    foreach ($taskFullPath in $tasks) {

        # Split "\Path\To\TaskName" into folder path + task name
        $taskFolder = Split-Path $taskFullPath -Parent
        $taskName = Split-Path $taskFullPath -Leaf

        # Respect config flags
        $isTelemetry = $taskFullPath -like "*Customer Experience*" -or $taskFullPath -like "*Feedback*" -or $taskFullPath -like "*Telemetry*"
        $isMaintenance = $taskFullPath -like "*Maintenance*" -or $taskFullPath -like "*WinSAT*" -or $taskFullPath -like "*Diagnostic*"

        if ($Config -and $Config.disableTelemetryTasks -eq $false -and $isTelemetry) {
            Write-ArcLog "Skipped (telemetry tasks preserved): $taskName"
            $skippedCount++
            continue
        }

        if ($Config -and $Config.disableMaintenanceTasks -eq $false -and $isMaintenance) {
            Write-ArcLog "Skipped (maintenance tasks preserved): $taskName"
            $skippedCount++
            continue
        }

        try {
            $task = Get-ScheduledTask -TaskName $taskName -TaskPath "$taskFolder\" -ErrorAction SilentlyContinue

            if (-not $task) {
                Write-ArcLog "Task not found (skipping): $taskFullPath"
                $notFoundCount++
                continue
            }

            if ($task.State -ne "Disabled") {
                Disable-ScheduledTask `
                    -TaskPath "$taskFolder\" `
                    -TaskName $taskName `
                    -ErrorAction SilentlyContinue | Out-Null

                Write-ArcLog "Disabled task: $taskFullPath"
                $disabledCount++
            }
            else {
                Write-ArcLog "Already disabled: $taskFullPath"
            }
        }
        catch {
            Write-ArcLog "Failed to disable task '$taskFullPath': $($_.Exception.Message)" "WARN"
        }
    }

    Write-ArcLog "Task engine complete — Disabled: $disabledCount | Skipped: $skippedCount | Not found: $notFoundCount"
}