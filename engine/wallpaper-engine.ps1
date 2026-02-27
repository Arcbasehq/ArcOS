function Invoke-WallpaperEngine {

    Write-ArcLog "Starting wallpaper replacement process."

    $WindowsWallpaperPath = "C:\Windows\Web\Wallpaper"
    $Windows4KPath        = "C:\Windows\Web\4K\Wallpaper"
    $SourcePath           = Join-Path $PSScriptRoot "..\wallpapers"

    # ===============================
    # Remove Default Windows Wallpapers
    # ===============================

    try {
        if (Test-Path $WindowsWallpaperPath) {
            Get-ChildItem $WindowsWallpaperPath -Recurse -File |
                Remove-Item -Force -ErrorAction SilentlyContinue
            Write-ArcLog "Default wallpapers removed."
        }

        if (Test-Path $Windows4KPath) {
            Get-ChildItem $Windows4KPath -Recurse -File |
                Remove-Item -Force -ErrorAction SilentlyContinue
            Write-ArcLog "Default wallpapers removed."
        }
    }
    catch {
        Write-ArcLog "Wallpaper cleanup failed." "WARN"
    }

    # ===============================
    # Copy Custom Wallpapers
    # ===============================

    if (-not (Test-Path $SourcePath)) {
        Write-ArcLog "Custom wallpaper folder not found." "ERROR"
        return
    }

    try {
        Get-ChildItem $SourcePath -File | ForEach-Object {
            Copy-Item $_.FullName $WindowsWallpaperPath -Force
            Write-ArcLog "Copied wallpaper: $($_.Name)"
        }
    }
    catch {
        Write-ArcLog "Failed copying custom wallpapers." "ERROR"
    }

    # ===============================
    # Set First Wallpaper as Default
    # ===============================

    $FirstWallpaper = Get-ChildItem $WindowsWallpaperPath -File | Select-Object -First 1

    if ($FirstWallpaper) {
        try {
            Set-ItemProperty `
                -Path "HKCU:\Control Panel\Desktop" `
                -Name "Wallpaper" `
                -Value $FirstWallpaper.FullName

            rundll32.exe user32.dll, UpdatePerUserSystemParameters

            Write-ArcLog "Wallpaper applied: $($FirstWallpaper.Name)"
        }
        catch {
            Write-ArcLog "Failed applying wallpaper." "WARN"
        }
    }

    Write-ArcLog "Wallpaper replacement complete."
}