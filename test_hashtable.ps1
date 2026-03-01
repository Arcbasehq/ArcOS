# Test hashtable with .Add() method

# Create a hashtable
$report = @{
    Timestamp = Get-Date
    Configuration = @{
        Profile = "balanced"
        EngineSettings = @{}
    }
}

# Test adding items dynamically
$engines = @("ServiceEngine", "AppxEngine", "TaskEngine")

foreach ($engine in $engines) {
    $engineSettings = @{
        Enabled = $true
        Config = @{test = "value"}
    }
    $report.Configuration.EngineSettings.Add($engine, $engineSettings)
}

# Convert to JSON
$json = $report | ConvertTo-Json -Depth 5
Write-Host "JSON Output:"
Write-Host $json

Write-Host "Test completed successfully!" -ForegroundColor Green