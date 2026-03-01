#!/usr/bin/env pwsh

# Basic syntax test for ArcOS

# Test 1: Hash table syntax
$testConfig = @{
    version = "1.0"
    profile = "balanced"
    engines = @{
        "ServiceEngine" = @{
            enabled = $true
            config = @{
                disableTelemetryServices = $true
            }
        }
    }
    advanced = @{
        autoReboot = $true
        verboseLogging = $false
    }
}

# Test 2: Foreach loop
foreach ($key in $testConfig.engines.Keys) {
    Write-Host "Engine: $key"
}

# Test 3: Function definition
function Test-Function {
    param (
        [string]$Message
    )
    return "Test: $Message"
}

# Test 4: Array syntax
$engines = @(
    "ServiceEngine",
    "TaskEngine",
    "AppxEngine"
)

# Test 5: JSON conversion
$json = $testConfig | ConvertTo-Json -Depth 5
Write-Host "JSON test successful: $($json.Length) characters"

Write-Host "All basic syntax tests passed!" -ForegroundColor Green