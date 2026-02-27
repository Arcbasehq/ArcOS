Write-ArcLog "Applying privacy settings..."

# Disable Advertising ID
$AdPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
New-Item -Path $AdPath -Force | Out-Null
Save-State "REG::$AdPath|Enabled" (Get-ItemProperty -Path $AdPath -Name "Enabled" -ErrorAction SilentlyContinue).Enabled
Set-ItemProperty -Path $AdPath -Name "Enabled" -Value 0 -Type DWord

# Disable Activity History
$ActPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
New-Item -Path $ActPath -Force | Out-Null
Save-State "REG::$ActPath|PublishUserActivities" (Get-ItemProperty -Path $ActPath -Name "PublishUserActivities" -ErrorAction SilentlyContinue).PublishUserActivities
Set-ItemProperty -Path $ActPath -Name "PublishUserActivities" -Value 0 -Type DWord

# Disable Location Access
$LocPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
New-Item -Path $LocPath -Force | Out-Null
Save-State "REG::$LocPath|DisableLocation" (Get-ItemProperty -Path $LocPath -Name "DisableLocation" -ErrorAction SilentlyContinue).DisableLocation
Set-ItemProperty -Path $LocPath -Name "DisableLocation" -Value 1 -Type DWord

Write-ArcLog "Privacy settings applied."