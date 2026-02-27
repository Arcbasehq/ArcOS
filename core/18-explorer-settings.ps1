Write-ArcLog "Configuring File Explorer settings..."

$ExplorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# Show file extensions
Save-State "REG::$ExplorerPath|HideFileExt" (Get-ItemProperty -Path $ExplorerPath -Name "HideFileExt" -ErrorAction SilentlyContinue).HideFileExt
Set-ItemProperty -Path $ExplorerPath -Name "HideFileExt" -Value 0 -Type DWord

# Show hidden files
Save-State "REG::$ExplorerPath|Hidden" (Get-ItemProperty -Path $ExplorerPath -Name "Hidden" -ErrorAction SilentlyContinue).Hidden
Set-ItemProperty -Path $ExplorerPath -Name "Hidden" -Value 1 -Type DWord

Write-ArcLog "Explorer settings configured."