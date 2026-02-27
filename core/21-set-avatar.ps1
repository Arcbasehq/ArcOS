Write-ArcLog "Applying ArcOS profile picture..."

$LogoPath = "$PSScriptRoot\..\wallpapers\pfp.png"

if (-not (Test-Path $LogoPath)) {
    Write-ArcLog "pfp.png not found." "WARN"
    return
}

# Account picture cache path
$AccountPicCache = "$env:AppData\Microsoft\Windows\AccountPictures"

if (-not (Test-Path $AccountPicCache)) {
    New-Item -ItemType Directory -Path $AccountPicCache -Force | Out-Null
}

# Save previous picture state (if exists)
$ExistingPics = Get-ChildItem $AccountPicCache -ErrorAction SilentlyContinue
foreach ($Pic in $ExistingPics) {
    Save-State "PFP::$($Pic.Name)" $Pic.FullName
}

# Replace current account picture
$NewPath = "$AccountPicCache\ArcOS.png"
Copy-Item $LogoPath $NewPath -Force

# Update registry to point to new image
$UserRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)"

New-Item -Path $UserRegPath -Force | Out-Null
Set-ItemProperty -Path $UserRegPath -Name "Image192" -Value $NewPath -ErrorAction SilentlyContinue
Set-ItemProperty -Path $UserRegPath -Name "Image448" -Value $NewPath -ErrorAction SilentlyContinue

Write-ArcLog "Profile picture updated. Sign out and back in to see changes."