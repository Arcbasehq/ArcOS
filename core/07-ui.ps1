Write-Host "Applying UI performance tweaks..."

# Disable Transparency Effects
Set-ItemProperty `
  -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
  -Name "EnableTransparency" -Value 0 -Type DWord

# Disable Window Animations (Visual Effects)
Set-ItemProperty `
  -Path "HKCU:\Control Panel\Desktop\WindowMetrics" `
  -Name "MinAnimate" -Value "0"

# Set Visual Effects to Best Performance
Set-ItemProperty `
  -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
  -Name "VisualFXSetting" -Value 2 -Type DWord

# Disable Taskbar Animations
Set-ItemProperty `
  -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
  -Name "TaskbarAnimations" -Value 0 -Type DWord

# Apply changes immediately
RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters

Write-Host "UI tweaks applied."