Write-ArcLog "Applying Windows UI settings..."

# Dark mode
$ThemePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
New-Item -Path $ThemePath -Force | Out-Null

Save-State "REG::$ThemePath|AppsUseLightTheme" (Get-ItemProperty -Path $ThemePath -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue).AppsUseLightTheme
Set-ItemProperty -Path $ThemePath -Name "AppsUseLightTheme" -Value 0 -Type DWord

# Disable transparency
Save-State "REG::$ThemePath|EnableTransparency" (Get-ItemProperty -Path $ThemePath -Name "EnableTransparency" -ErrorAction SilentlyContinue).EnableTransparency
Set-ItemProperty -Path $ThemePath -Name "EnableTransparency" -Value 0 -Type DWord

Write-ArcLog "UI settings applied."