function Invoke-ServiceEngine {
    param (
        [object]$Config
    )

    Write-ArcLog "Starting service optimization."

    # Load service list from manifest
    $manifestPath = if ($Global:ArcManifestDir) {
        Join-Path $Global:ArcManifestDir 'services.json'
    }
    else {
        Join-Path $PSScriptRoot '..\manifests\services.json'
    }

    if (-not (Test-Path $manifestPath)) {
        Write-ArcLog "services.json manifest not found." "WARN"
        return
    }

    $services = Get-Content $manifestPath -Raw | ConvertFrom-Json

    $disabledCount = 0
    $manualCount = 0
    $skippedCount = 0

    foreach ($entry in $services) {

        # Respect config flags
        $isXbox = $entry.Name -like "Xbox*" -or $entry.Name -like "Xbl*"
        $isTelemetry = $entry.Name -eq "DiagTrack" -or $entry.Name -eq "dmwappushservice" -or $entry.Name -eq "WerSvc" -or $entry.Name -eq "DPS" -or $entry.Name -eq "WdiServiceHost" -or $entry.Name -eq "WdiSystemHost"

        if ($Config -and $Config.disableXboxServices -eq $false -and $isXbox) {
            Write-ArcLog "Skipped (Xbox services preserved): $($entry.Name)"
            $skippedCount++
            continue
        }

        if ($Config -and $Config.disableTelemetryServices -eq $false -and $isTelemetry) {
            Write-ArcLog "Skipped (telemetry services preserved): $($entry.Name)"
            $skippedCount++
            continue
        }

        try {
            $svc = Get-Service -Name $entry.Name -ErrorAction SilentlyContinue
            if (-not $svc) {
                Write-ArcLog "Service not found (skipping): $($entry.Name)"
                $skippedCount++
                continue
            }

            if ($entry.StartupType -eq "Disabled") {
                Stop-Service -Name $entry.Name -Force -ErrorAction SilentlyContinue
                Set-Service  -Name $entry.Name -StartupType Disabled -ErrorAction SilentlyContinue
                Write-ArcLog "Disabled: $($entry.Name) — $($entry.Description)"
                $disabledCount++
            }
            elseif ($entry.StartupType -eq "Manual") {
                Set-Service -Name $entry.Name -StartupType Manual -ErrorAction SilentlyContinue
                Write-ArcLog "Set to Manual: $($entry.Name) — $($entry.Description)"
                $manualCount++
            }
        }
        catch {
            Write-ArcLog "Failed to configure service '$($entry.Name)': $($_.Exception.Message)" "WARN"
        }
    }

    $runningAfter = (Get-Service | Where-Object { $_.Status -eq "Running" }).Count
    $totalServices = (Get-Service).Count

    Write-ArcLog "Service engine complete — Disabled: $disabledCount | Manual: $manualCount | Skipped: $skippedCount"
    Write-ArcLog "Running services after: $runningAfter / $totalServices total"
}