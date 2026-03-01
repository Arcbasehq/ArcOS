# Test script to check PowerShell syntax

# Test hash table syntax
$testHash = @{
    version = "1.0"
    profile = "balanced"
    engines = @{}
    advanced = @{
        createRestorePoint = $true
        skipCompatibilityCheck = $false
        dryRunMode = $false
        verboseLogging = $false
        autoReboot = $true
    }
}

# Test foreach loop
foreach ($engine in $testHash.Keys) {
    Write-Host "Engine: $engine"
}

# Test nested hash
$testHash.engines."ServiceEngine" = @{
    enabled = $true
    config = @{
        disableTelemetryServices = $true
    }
}

Write-Host "Syntax test completed successfully"
$testHash | ConvertTo-Json -Depth 5