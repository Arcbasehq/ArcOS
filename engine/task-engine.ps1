function Invoke-TaskEngine {

    $manifest = Join-Path $PSScriptRoot '..\manifests\tasks.json'
    if (-not (Test-Path $manifest)) { return }

    $tasks = Get-Content $manifest -Raw | ConvertFrom-Json

    foreach ($task in $tasks) {

        $path = Split-Path $task -Parent
        $name = Split-Path $task -Leaf

        Disable-ScheduledTask `
            -TaskPath "$path\" `
            -TaskName $name `
            -ErrorAction SilentlyContinue

        Write-ArcLog "Disabled task: $task"
    }
}