function Invoke-RegistryEngine {

    $manifest = if ($Global:ArcManifestDir) {
        Join-Path $Global:ArcManifestDir 'registry.json'
    }
    else {
        Join-Path $PSScriptRoot '..\manifests\registry.json'
    }
    if (-not (Test-Path $manifest)) { return }

    $entries = Get-Content $manifest -Raw | ConvertFrom-Json

    foreach ($entry in $entries) {

        New-Item -Path $entry.Path -Force -ErrorAction SilentlyContinue | Out-Null

        Set-ItemProperty `
            -Path $entry.Path `
            -Name $entry.Name `
            -Value $entry.Value `
            -Type $entry.Type `
            -ErrorAction SilentlyContinue

        Write-ArcLog "Registry updated: $($entry.Path)\$($entry.Name)"
    }
}