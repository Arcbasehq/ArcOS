Write-ArcLog "Configuring Windows Update settings..."

$WUPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
New-Item -Path $WUPath -Force | Out-Null

Save-State "REG::$WUPath|NoAutoUpdate" (Get-ItemProperty -Path $WUPath -Name "NoAutoUpdate" -ErrorAction SilentlyContinue).NoAutoUpdate
Set-ItemProperty -Path $WUPath -Name "NoAutoUpdate" -Value 0 -Type DWord

# Disable automatic restart
Save-State "REG::$WUPath|NoAutoRebootWithLoggedOnUsers" (Get-ItemProperty -Path $WUPath -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue).NoAutoRebootWithLoggedOnUsers
Set-ItemProperty -Path $WUPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord

Write-ArcLog "Windows Update settings configured."