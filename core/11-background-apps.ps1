Write-ArcLog "Disabling background apps..."

$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"

New-Item -Path $RegPath -Force | Out-Null

$Current = Get-ItemProperty -Path $RegPath -Name "GlobalUserDisabled" -ErrorAction SilentlyContinue
if ($Current) {
    Save-State "REG::$RegPath|GlobalUserDisabled" $Current.GlobalUserDisabled
}

Set-ItemProperty -Path $RegPath -Name "GlobalUserDisabled" -Value 1 -Type DWord

Write-ArcLog "Background apps disabled."