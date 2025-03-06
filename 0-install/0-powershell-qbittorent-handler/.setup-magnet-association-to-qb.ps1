# Setup the magnet association to trigger magnet send script

# Define the script path where the send-magnet-to-qb.ps1 is stored
$scriptPath = "C:\Users\roysu\send-magnet-to-qb.ps1"  # Update with the actual path to the PowerShell script

# Create and set the registry key for the magnet protocol
$regPath = "HKCU:\Software\Classes\magnet"
if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force }
Set-ItemProperty -Path $regPath -Name "(Default)" -Value "URL:Magnet Protocol"
Set-ItemProperty -Path $regPath -Name "URL Protocol" -Value ""

# Create the shell key for the open command
$regShellPath = "$regPath\shell\open\command"
if (-not (Test-Path $regShellPath)) { New-Item -Path $regShellPath -Force }

# Set the command to execute the PowerShell script with the magnet link as an argument
# Set-ItemProperty -Path $regShellPath -Name "(Default)" -Value "`"powershell.exe`" -ExecutionPolicy Bypass -File `"$scriptPath`" `"%1`""
# Doing the above directly displays a PowerShell console briefly.
# Hence, use the below to prevent this by first running a .vbs which then calls the .ps1
$vbsScriptPath = "C:\Users\roysu\send-magnet-to-qb.vbs"
Set-ItemProperty -Path $regShellPath -Name "(Default)" -Value "`"wscript.exe`" `"$vbsScriptPath`" `"%1`""

# Set-ItemProperty -Path $regShellPath -Name "(Default)" -Value "`"wscript.exe`" `"`"$scriptPath`" `"%1`""
# $regPath = "HKCU:\Software\Classes\magnet\shell\open\command"
# Set-ItemProperty -Path $regPath -Name "(Default)" -Value "`"wscript.exe`" `"`"$scriptPath`" `"%1`""

Write-Host "Magnet protocol association has been created successfully."
