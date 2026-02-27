function Invoke-AvatarEngine {

    Write-ArcLog "Replacing user profile picture."

    $Source = Join-Path $PSScriptRoot "..\wallpapers\pfp.png"

    if (-not (Test-Path $Source)) {
        Write-ArcLog "pfp.png not found." "ERROR"
        return
    }

    $AccountPicDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\AccountPictures"

    if (-not (Test-Path $AccountPicDir)) {
        New-Item -Path $AccountPicDir -ItemType Directory -Force | Out-Null
    }

    # Windows stores multiple sizes
    $Sizes = @(
        "Image32.png",
        "Image40.png",
        "Image48.png",
        "Image96.png",
        "Image192.png",
        "Image200.png",
        "Image240.png",
        "Image448.png"
    )

    foreach ($size in $Sizes) {
        try {
            Copy-Item $Source (Join-Path $AccountPicDir $size) -Force
            Write-ArcLog "Updated $size"
        }
        catch {
            Write-ArcLog "Failed writing $size" "WARN"
        }
    }

    # Update registry reference
    try {
        $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$env:USERNAME"
        if (-not (Test-Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
        }

        Set-ItemProperty `
            -Path $RegPath `
            -Name "Image" `
            -Value (Join-Path $AccountPicDir "Image192.png") `
            -ErrorAction SilentlyContinue

        Write-ArcLog "Registry updated."
    }
    catch {
        Write-ArcLog "Registry update failed." "WARN"
    }

    # Force UI refresh
    try {
        Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
        Start-Process "explorer.exe"
        Write-ArcLog "Explorer restarted."
    }
    catch {}

    Write-ArcLog "Profile picture replacement complete."
}