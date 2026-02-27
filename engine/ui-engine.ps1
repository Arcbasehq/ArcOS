function Invoke-UIEngine {

    Write-ArcLog "Disabling Windows UI animations."

    try {

        # ===============================
        # Disable Transparency
        # ===============================
        Set-ItemProperty `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
            -Name "EnableTransparency" `
            -Value 0 `
            -ErrorAction SilentlyContinue

        Write-ArcLog "Transparency disabled."

        # ===============================
        # Disable Min/Max Animations
        # ===============================
        Set-ItemProperty `
            -Path "HKCU:\Control Panel\Desktop\WindowMetrics" `
            -Name "MinAnimate" `
            -Value "0" `
            -ErrorAction SilentlyContinue

        Write-ArcLog "Minimize/maximize animations disabled."

        # ===============================
        # Disable Taskbar Animations
        # ===============================
        Set-ItemProperty `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
            -Name "TaskbarAnimations" `
            -Value 0 `
            -ErrorAction SilentlyContinue

        Write-ArcLog "Taskbar animations disabled."

        # ===============================
        # Force Best Performance VisualFX
        # ===============================
        Set-ItemProperty `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
            -Name "VisualFXSetting" `
            -Value 2 `
            -ErrorAction SilentlyContinue

        Write-ArcLog "Visual effects set to best performance."

        # ===============================
        # Disable Advanced Visual Effects
        # ===============================
        $VisualEffectsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

        $AdvancedTweaks = @{
            "ListviewAlphaSelect" = 0
            "ListviewShadow"      = 0
            "IconsOnly"           = 1
        }

        foreach ($key in $AdvancedTweaks.Keys) {
            Set-ItemProperty `
                -Path $VisualEffectsPath `
                -Name $key `
                -Value $AdvancedTweaks[$key] `
                -ErrorAction SilentlyContinue
        }

        Write-ArcLog "Advanced UI effects disabled."

        # ===============================
        # Apply Immediately
        # ===============================
        rundll32.exe user32.dll, UpdatePerUserSystemParameters

        Write-ArcLog "UI animation removal complete."
    }
    catch {
        Write-ArcLog "UI optimization failed." "ERROR"
    }
}