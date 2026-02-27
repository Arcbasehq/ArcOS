if ($Config.Mode -ne "Performance" -and $Config.Mode -ne "Extreme") { return }

Write-ArcLog "Applying Gaming Profile..."

# Disable Game DVR
$DvrPath = "HKCU:\System\GameConfigStore"
New-Item -Path $DvrPath -Force | Out-Null
Save-State "REG::$DvrPath|GameDVR_Enabled" (Get-ItemProperty -Path $DvrPath -Name "GameDVR_Enabled" -ErrorAction SilentlyContinue).GameDVR_Enabled
Set-ItemProperty -Path $DvrPath -Name "GameDVR_Enabled" -Value 0 -Type DWord

# Disable Xbox Game Bar
$BarPath = "HKCU:\Software\Microsoft\GameBar"
New-Item -Path $BarPath -Force | Out-Null
Save-State "REG::$BarPath|AutoGameModeEnabled" (Get-ItemProperty -Path $BarPath -Name "AutoGameModeEnabled" -ErrorAction SilentlyContinue).AutoGameModeEnabled
Set-ItemProperty -Path $BarPath -Name "AutoGameModeEnabled" -Value 0 -Type DWord

# Enable Hardware GPU Scheduling
$GpuPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
Save-State "REG::$GpuPath|HwSchMode" (Get-ItemProperty -Path $GpuPath -Name "HwSchMode" -ErrorAction SilentlyContinue).HwSchMode
Set-ItemProperty -Path $GpuPath -Name "HwSchMode" -Value 2 -Type DWord

Write-ArcLog "Gaming profile applied."