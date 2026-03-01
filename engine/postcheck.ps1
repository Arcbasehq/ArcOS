function Invoke-Postcheck {

    Write-ArcLog "Running post-deployment verification."

    try {
        $ProjectRoot = Split-Path $PSScriptRoot -Parent
        $reportsPath = Join-Path $ProjectRoot "reports"
        $baselinePath = Join-Path $reportsPath "baseline.json"

        # =====================================================
        # Load Baseline
        # =====================================================

        if (-not (Test-Path $baselinePath)) {
            Write-ArcLog "No baseline found — skipping comparison." "WARN"
            return
        }

        $baseline = Get-Content $baselinePath -Raw | ConvertFrom-Json
        $osInfo = Get-CimInstance Win32_OperatingSystem

        # =====================================================
        # Capture Post-Run State
        # =====================================================

        $afterServicesRunning = (Get-Service | Where-Object { $_.Status -eq "Running" }).Count
        $afterServicesTotal = (Get-Service).Count
        $afterTasksEnabled = (Get-ScheduledTask | Where-Object { $_.State -ne "Disabled" }).Count
        $afterFreeRAM_MB = [math]::Round($osInfo.FreePhysicalMemory / 1KB)

        $serviceDelta = $baseline.ServicesRunning - $afterServicesRunning
        $taskDelta = $baseline.TasksEnabled - $afterTasksEnabled
        $ramDelta = $afterFreeRAM_MB - $baseline.FreeRAM_MB

        # =====================================================
        # Summary Output
        # =====================================================

        Write-Host ""
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "  ArcOS Post-Deployment Benchmark Report"    -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "  Services running:" -NoNewline
        Write-Host "  $($baseline.ServicesRunning) → $afterServicesRunning" -NoNewline -ForegroundColor White
        if ($serviceDelta -gt 0) {
            Write-Host "  (-$serviceDelta)" -ForegroundColor Green
        }
        else {
            Write-Host "" -ForegroundColor Gray
        }

        Write-Host "  Scheduled tasks enabled:" -NoNewline
        Write-Host "  $($baseline.TasksEnabled) → $afterTasksEnabled" -NoNewline -ForegroundColor White
        if ($taskDelta -gt 0) {
            Write-Host "  (-$taskDelta)" -ForegroundColor Green
        }
        else {
            Write-Host "" -ForegroundColor Gray
        }

        Write-Host "  Free RAM:" -NoNewline
        Write-Host "  $($baseline.FreeRAM_MB) MB → $afterFreeRAM_MB MB" -NoNewline -ForegroundColor White
        if ($ramDelta -gt 0) {
            Write-Host "  (+${ramDelta} MB)" -ForegroundColor Green
        }
        elseif ($ramDelta -lt 0) {
            Write-Host "  (${ramDelta} MB)" -ForegroundColor Yellow
        }
        else {
            Write-Host "" -ForegroundColor Gray
        }

        Write-Host ""
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""

        # =====================================================
        # Save Postcheck Report
        # =====================================================

        $postcheck = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Baseline  = $baseline
            After     = @{
                ServicesRunning = $afterServicesRunning
                ServicesTotal   = $afterServicesTotal
                TasksEnabled    = $afterTasksEnabled
                FreeRAM_MB      = $afterFreeRAM_MB
            }
            Delta     = @{
                ServicesDisabled = $serviceDelta
                TasksDisabled    = $taskDelta
                RAMFreed_MB      = $ramDelta
            }
        }

        $postcheckPath = Join-Path $reportsPath "postcheck.json"
        $postcheck | ConvertTo-Json -Depth 5 | Set-Content -Path $postcheckPath -Encoding UTF8

        Write-ArcLog "Post-deployment report saved to $postcheckPath"
    }
    catch {
        Write-ArcLog "Post-deployment check failed: $($_.Exception.Message)" "ERROR"
    }

    Write-ArcLog "Post-deployment verification complete."
}