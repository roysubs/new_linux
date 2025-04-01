#!/usr/bin/env pwsh

# resolve-iprange.ps1

param (
    [string]$StartAddress,
    [string]$EndAddress,
    [switch]$Verbose
)

# Ensure ping-range.ps1 exists
$PingScript = "./ping-iprange.ps1"
if (!(Test-Path $PingScript)) {
    Write-Host "Error: ping-range.ps1 not found!" -ForegroundColor Red
    exit 1
}

# Run ping-range.ps1 to get a list of active IPs
$ActiveIPs = & $PingScript -StartAddress $StartAddress -EndAddress $EndAddress | Select-String -Pattern "(\d+\.\d+\.\d+\.\d+)" | ForEach-Object { $_.Matches.Groups[1].Value }

if ($Verbose) {
    Write-Host "Active IPs found:" -ForegroundColor Cyan
    $ActiveIPs | ForEach-Object { Write-Host $_ }
}

# Resolve hostnames for active IPs
$Results = @()
foreach ($IP in $ActiveIPs) {
    $Hostname = [System.Net.Dns]::GetHostEntry($IP).HostName 2>$null
    if (-not $Hostname) { $Hostname = "N/A" }
    $Results += [PSCustomObject]@{
        IP       = $IP
        Hostname = $Hostname
    }
}

# Output results
$Results | Format-Table -AutoSize

