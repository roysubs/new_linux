To set up magnet links so that they automatically trigger a PowerShell script that sends the magnet link to your qBittorrent Web UI, we will need to modify the Windows registry to associate the magnet protocol with a script. This script will send the magnet link to qBittorrent using its Web API. Here's a step-by-step guide for the process:

Step 1: Create the PowerShell Script
Create a PowerShell script that will receive the magnet link and send it to your qBittorrent Web UI running on 192.168.1.140:8080.

Example PowerShell Script (send-magnet-to-qb.ps1)
powershell
Copy
Edit
param (
    [string]$magnetLink
)

# qBittorrent Web UI information
$qbWebUIHost = "http://192.168.1.140:8080"  # IP of your qBittorrent server
$username = "admin"  # Your qBittorrent Web UI username
$password = "adminadmin"  # Your qBittorrent Web UI password

# Authenticate with qBittorrent Web UI
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$response = Invoke-WebRequest -Uri "$qbWebUIHost/api/v2/auth/login" -Method Post -Body @{
    username = $username
    password = $password
} -SessionVariable session

# Add the magnet link to qBittorrent
$response = Invoke-WebRequest -Uri "$qbWebUIHost/api/v2/torrents/add" -Method Post -Body @{
    magnetLink = $magnetLink
} -WebSession $session

# Check if the request was successful
if ($response.StatusCode -eq 200) {
    Write-Host "Magnet link added successfully!"
} else {
    Write-Host "Failed to add magnet link. Status code: $($response.StatusCode)"
}
Script Explanation:
This script takes the magnet link as a parameter.
It then authenticates to the qBittorrent Web UI using the provided credentials.
Finally, it sends the magnet link to qBittorrent using the Web API.
Step 2: Modify the Windows Registry to Associate the Magnet Protocol
We need to create a custom registry key that associates the magnet protocol with our PowerShell script. The registry modification ensures that whenever you click on a magnet link in any browser, Windows will call the script we created.

Here's a PowerShell script that will set up the required registry keys:

PowerShell Script to Modify the Registry (setup-magnet-association.ps1)
powershell
Copy
Edit
# Define the script path where the send-magnet-to-qb.ps1 is stored
$scriptPath = "C:\path\to\your\send-magnet-to-qb.ps1"  # Update with the actual path to the PowerShell script

# Define the registry path for the magnet protocol
$regPath = "HKCU:\Software\Classes\magnet"

# Create the registry key for the magnet protocol
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force
}

# Set the default value for the magnet protocol
Set-ItemProperty -Path $regPath -Name "(Default)" -Value "URL:Magnet Protocol"
Set-ItemProperty -Path $regPath -Name "URL Protocol" -Value ""

# Create the shell key for the open command
$regShellPath = "$regPath\shell\open\command"
if (-not (Test-Path $regShellPath)) {
    New-Item -Path $regShellPath -Force
}

# Set the command to execute the PowerShell script with the magnet link as an argument
Set-ItemProperty -Path $regShellPath -Name "(Default)" -Value "`"powershell.exe`" -ExecutionPolicy Bypass -File `"$scriptPath`" `"%1`""

Write-Host "Magnet protocol association has been created successfully."
Registry Modifications:
HKCU\Software\Classes\magnet: This is the registry path where we associate the magnet protocol.
Default: Sets the label for the magnet protocol.
URL Protocol: Ensures the protocol is recognized by Windows.
HKCU\Software\Classes\magnet\shell\open\command: This sets the command that will run when you click a magnet link.
The command runs PowerShell, bypasses execution policy (if required), and executes the PowerShell script (send-magnet-to-qb.ps1) with the magnet link (%1) passed as an argument.
Step 3: Run the PowerShell Script
First, update the $scriptPath variable in the setup-magnet-association.ps1 script with the actual path to your send-magnet-to-qb.ps1 script.
Open PowerShell as Administrator (to modify the registry).
Run the setup-magnet-association.ps1 script.
This will update the registry and associate the magnet protocol with the PowerShell script that sends the magnet link to qBittorrent.

Step 4: Testing the Setup
After running the script, you should now be able to:

Click on a magnet link from any website, and Windows should trigger the PowerShell script automatically.
The magnet link will be sent to qBittorrent via the Web API and added to the queue.
Step 5: Optional - Open Ports for Web UI
Make sure that your qBittorrent Web UI is accessible remotely (if not already set up) by opening the necessary port on your Windows firewall (if applicable). For example, open port 8080 if it's not already open:

powershell
Copy
Edit
New-NetFirewallRule -DisplayName "Allow qBittorrent Web UI" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
Recap:
The PowerShell script sends the magnet link to qBittorrent via its Web API.
We modify the Windows registry to associate the magnet protocol with this script.
Clicking on a magnet link will automatically add it to your qBittorrent Web UI.
Let me know if you need any further clarifications!
