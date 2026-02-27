Write-ArcLog "Applying Memory Optimization..."

# ===============================
# 1. Disable SysMain (Superfetch)
# ===============================

$SysMain = Get-Service -Name "SysMain" -ErrorAction SilentlyContinue

if ($SysMain) {
    Save-State "SERVICE::SysMain" $SysMain.StartType

    if ($SysMain.Status -ne "Stopped") {
        Stop-Service "SysMain" -Force -ErrorAction SilentlyContinue
    }

    Set-Service "SysMain" -StartupType Disabled
    Write-ArcLog "SysMain disabled."
}

# ===============================
# 2. Disable Background Apps
# ===============================

$BgPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
New-Item -Path $BgPath -Force | Out-Null

$CurrentBg = Get-ItemProperty -Path $BgPath -Name "GlobalUserDisabled" -ErrorAction SilentlyContinue
if ($CurrentBg) {
    Save-State "REG::$BgPath|GlobalUserDisabled" $CurrentBg.GlobalUserDisabled
}

Set-ItemProperty -Path $BgPath -Name "GlobalUserDisabled" -Value 1 -Type DWord
Write-ArcLog "Background apps disabled."

# ===============================
# 3. Disable Transparency Effects
# ===============================

$ThemePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
New-Item -Path $ThemePath -Force | Out-Null

$Trans = Get-ItemProperty -Path $ThemePath -Name "EnableTransparency" -ErrorAction SilentlyContinue
if ($Trans) {
    Save-State "REG::$ThemePath|EnableTransparency" $Trans.EnableTransparency
}

Set-ItemProperty -Path $ThemePath -Name "EnableTransparency" -Value 0 -Type DWord
Write-ArcLog "Transparency disabled."

# ===============================
# 4. Reduce Visual Effects
# ===============================

$VisualPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
New-Item -Path $VisualPath -Force | Out-Null

$Visual = Get-ItemProperty -Path $VisualPath -Name "VisualFXSetting" -ErrorAction SilentlyContinue
if ($Visual) {
    Save-State "REG::$VisualPath|VisualFXSetting" $Visual.VisualFXSetting
}

Set-ItemProperty -Path $VisualPath -Name "VisualFXSetting" -Value 2 -Type DWord  # Best Performance
Write-ArcLog "Visual effects reduced."

# ===============================
# 5. Optional: Clear Standby List (Immediate RAM Drop)
# ===============================

try {
    Write-ArcLog "Clearing standby memory..."
    rundll32.exe advapi32.dll,ProcessIdleTasks
}
catch {
    Write-ArcLog "Standby memory clear failed." "WARN"
}

Write-ArcLog "Memory optimization complete."