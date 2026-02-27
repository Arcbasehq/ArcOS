Write-Host "Applying ArcOS wallpaper..."

$WallpaperSource = "$PSScriptRoot\..\wallpapers\dark.jpg"
$DestinationDir = "C:\ArcOS"

# Create directory if it doesn't exist
if (-not (Test-Path $DestinationDir)) {
    New-Item -ItemType Directory -Path $DestinationDir | Out-Null
}

$DestinationPath = "$DestinationDir\wallpaper.jpg"

# Copy wallpaper
Copy-Item $WallpaperSource -Destination $DestinationPath -Force

# Set wallpaper via SystemParametersInfo
Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SystemParametersInfo(
        int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

[Wallpaper]::SystemParametersInfo(20, 0, $DestinationPath, 3)

Write-Host "Wallpaper applied."