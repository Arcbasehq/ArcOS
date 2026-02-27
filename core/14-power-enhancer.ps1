Write-ArcLog "Enhancing power plan..."

# Save current plan
$CurrentPlan = (powercfg /getactivescheme)
Save-State "POWERPLAN" $CurrentPlan

# Activate High Performance
powercfg -setactive SCHEME_MIN

# Disable USB selective suspend
powercfg -change -usbsetting 0

# Disable monitor timeout (optional performance behavior)
powercfg -change -monitor-timeout-ac 0

Write-ArcLog "Power plan enhanced."