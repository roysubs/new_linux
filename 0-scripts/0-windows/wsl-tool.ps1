#!/usr/bin/env pwsh

<#
.SYNOPSIS
    WSL Lifecycle Management Tool
.DESCRIPTION
    Idempotent, user-friendly script to manage WSL and its distros.
#>

param(
    [string]$installDistro,
    [string[]]$exportDistro,
    [string]$restoreDistro,
    [string]$wipeDistro,
    [switch]$installWsl,
    [switch]$info
)

function Show-Help {
    Write-Host ""
    Write-Host "WSL Tool     Usage: ./WSL-Tool.ps1 [--option] <args>" -ForegroundColor Cyan
    Write-Host "Options:"
    Write-Host "  --install-wsl                     Install WSL (steps through reboot etc.)"
    Write-Host "  --install-distro <name>           Install specified distro, or list if omitted"
    Write-Host "  --export-distro <name> <file>     Export distro to backup file"
    Write-Host "  --restore-distro <file> [name]    Restore distro from file, optional new name"
    Write-Host "  --wipe-distro <name>              Completely remove a distro (with warnings)"
    Write-Host "  --info                            Show all WSL diagnostics and distro info"
    Write-Host ""
}

function Show-Info {
    Write-Host "`nWSL Status:" -ForegroundColor Yellow
    wsl --status 2>$null | ForEach-Object { Write-Host "  $_" }

    $distros = wsl -l -v 2>$null | Select-Object -Skip 1
    if ($distros) {
        Write-Host "`nInstalled Distros:" -ForegroundColor Yellow
        foreach ($distro in $distros) {
            $name = $distro -replace '\s{2,}', ',' | ConvertFrom-Csv -Header Name,State,Version
            $vhdPath = "$env:USERPROFILE\AppData\Local\Packages\*${($name.Name -replace ' ', '_')}*\LocalState\ext4.vhdx"
            $vhdFile = Get-ChildItem -Path $vhdPath -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($vhdFile) {
                Write-Host "  $($name.Name): $($name.State), WSL$($name.Version), VHDX: $($vhdFile.Length / 1MB -as [int]) MB"
            } else {
                Write-Host "  $($name.Name): $($name.State), WSL$($name.Version), VHDX: not found"
            }
        }
    } else {
        Write-Host "  No distros found."
    }
}

function Install-WSL {
    Write-Host "Checking and installing WSL..." -ForegroundColor Green
    if (-not (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq 'Enabled') {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
        Write-Host "WSL feature installed. Please reboot the system to complete." -ForegroundColor Yellow
    } else {
        Write-Host "WSL already installed." -ForegroundColor Green
    }
}

# Stub functions — real logic will go in later
function Install-Distro($name) { Write-Host "Installing Distro: $name (todo)" }
function Export-Distro($args) { Write-Host "Export Distro: $($args -join ', ') (todo)" }
function Restore-Distro($args) { Write-Host "Restore Distro: $($args -join ', ') (todo)" }
function Wipe-Distro($name) { Write-Host "Wipe Distro: $name (todo)" }

# Main execution
if ($PSBoundParameters.Count -eq 0) {
    Show-Info
    Show-Help
    exit
}

if ($info) { Show-Info }
if ($installWsl) { Install-WSL }
if ($installDistro) { Install-Distro $installDistro }
if ($exportDistro.Count -gt 0) { Export-Distro $exportDistro }
if ($restoreDistro) { Restore-Distro $restoreDistro }
if ($wipeDistro) { Wipe-Distro $wipeDistro }

