$Script:LogFile = Join-Path $PSScriptRoot '..\reports\arcos.log'

function Write-ArcLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp][$Level] $Message"

    Write-Host $line

    try { Add-Content -Path $Script:LogFile -Value $line } catch {}
}