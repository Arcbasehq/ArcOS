function Invoke-PolicyEngine {

    $manifest = if ($Global:ArcManifestDir) {
        Join-Path $Global:ArcManifestDir 'policies.json'
    }
    else {
        Join-Path $PSScriptRoot '..\manifests\policies.json'
    }
    if (-not (Test-Path $manifest)) { return }

    $policies = Get-Content $manifest -Raw | ConvertFrom-Json

    foreach ($policy in $policies) {

        New-Item -Path $policy.Path -Force -ErrorAction SilentlyContinue | Out-Null

        Set-ItemProperty `
            -Path $policy.Path `
            -Name $policy.Name `
            -Value $policy.Value `
            -ErrorAction SilentlyContinue

        Write-ArcLog "Policy applied: $($policy.Name)"
    }
}