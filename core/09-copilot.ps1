if (-not $Global:IsWindows11) { return }

Write-ArcLog "Disabling Windows Copilot..."

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Force | Out-Null
Set-ItemProperty `
  -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" `
  -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord