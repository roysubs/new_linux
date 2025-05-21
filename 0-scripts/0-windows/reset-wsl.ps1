<#
.SYNOPSIS
Uninstalls and wipes a selected WSL distribution with confirmation and backup/reinstall options.

.DESCRIPTION
This script guides the user through selecting a WSL distribution to uninstall.
It offers to export the distribution's filesystem as a backup before proceeding.
It uses aggressive confirmation prompts to prevent accidental data loss.
Finally, it offers to install a fresh WSL distribution after the uninstallation.

.NOTES
Author: Roy Wiseman
Version: 1.0
Date: 2025-05-12
Requires: PowerShell, WSL installed and configured.

DISCLAIMER: This script performs destructive actions (deleting data).
Use with extreme caution. The author is not responsible for any data loss.
Ensure you have backups if the export option is not sufficient or fails.
#>

# --- Configuration ---
$ExportBackupDirectory = "$([Environment]::GetFolderPath('Desktop'))\WSL_Backups" # Default backup location (User's Desktop)
# ---------------------

function Show-Message {
    param(
        [string]$Message,
        [string]$Type = "Information" # Can be "Information", "Warning", "Error", "Success"
    )

    $Color = "White"
    switch ($Type) {
        "Information" { $Color = "Cyan" }
        "Warning"     { $Color = "Yellow" }
        "Error"       { $Color = "Red" }
        "Success"     { $Color = "Green" }
    }
    Write-Host "$Message" -ForegroundColor $Color
}

function Get-WslDistributions {
    try {
        # Get WSL distributions, filter out the header, and select the name
        $distros = & wsl.exe --list --verbose | Select-Object -Skip 1 | ForEach-Object {
            # Split line by whitespace, ignoring multiple spaces, and take the last part (the name)
            ($_.Trim() -split '\s+', 3)[-1]
        }
        return $distros | Where-Object { $_ -ne "" } # Filter out any empty lines
    } catch {
        Show-Message "Error listing WSL distributions: $($_.Exception.Message)" -Type "Error"
        return $null
    }
}

function Get-OnlineWslDistributions {
    try {
        Show-Message "Fetching available distributions online..." -Type "Information"
        # Get online distributions, filter out the header, and select the name
         $distros = & wsl.exe --list --online | Select-Object -Skip 1 | ForEach-Object {
            # Split line by whitespace, ignoring multiple spaces, and take the first part (the name)
            ($_.Trim() -split '\s+', 2)[0]
        }
        return $distros | Where-Object { $_ -ne "" } # Filter out any empty lines
    } catch {
         Show-Message "Error fetching online WSL distributions: $($_.Exception.Message)" -Type "Error"
         Show-Message "Check your internet connection or try listing manually with 'wsl --list --online'" -Type "Information"
        return $null
    }
}


Show-Message @"
 _____ _ _ _   _ _____ _ _       __     _
|  |  | | | | | |  |  |_| |     |  |   |_|
|     |_|_| |___|  |  | | |___  |  |___| |
|__|__|___|_|   |__|__|_|_|___| |__|___|_|

This script will help you uninstall and PERMANENTLY WIPE a WSL instance.
Please read all prompts CAREFULLY.

"@ -Type "Warning"

# --- Step 1: Select Distribution ---
$installedDistros = Get-WslDistributions

if (-not $installedDistros) {
    Show-Message "No WSL distributions found. Nothing to uninstall." -Type "Information"
    exit
}

Show-Message "Installed WSL Distributions:" -Type "Information"
for ($i = 0; $i -lt $installedDistros.Length; $i++) {
    Write-Host "$($i + 1). $($installedDistros[$i])"
}

$selectedDistro = $null
$distroIndex = -1

while ($selectedDistro -eq $null) {
    $inputChoice = Read-Host "Enter the number of the distribution to uninstall, or 'q' to quit"
    if ($inputChoice -ceq 'q') {
        Show-Message "Operation cancelled." -Type "Information"
        exit
    }

    if ($inputChoice -match '^\d+$') {
        $distroIndex = [int]$inputChoice - 1
        if ($distroIndex -ge 0 -and $distroIndex -lt $installedDistros.Length) {
            $selectedDistro = $installedDistros[$distroIndex]
        } else {
            Show-Message "Invalid number. Please enter a number from the list." -Type "Warning"
        }
    } else {
        Show-Message "Invalid input. Please enter a number or 'q'." -Type "Warning"
    }
}

Show-Message "You selected: $($selectedDistro)" -Type "Information"

# --- Step 2: Aggressive Confirmation 1 ---
Show-Message @"

=====================================================================
AGGRESSIVE CONFIRMATION REQUIRED
=====================================================================
You are about to begin the process to UNINSTALL and WIPE the
'$selectedDistro' WSL distribution.

This process, if completed, WILL DELETE ALL DATA inside this instance.
This includes all files, installed software, and user configurations.

Data loss WILL occur unless you perform a backup EXPORT later in this script.

Type 'YES' (in all caps) to PROCEED with the uninstallation process for '$selectedDistro'.
Anything else will CANCEL.
=====================================================================
"@ -Type "Error"

$confirmProceed = Read-Host "Enter 'YES' to confirm"

if ($confirmProceed -ne "YES") {
    Show-Message "Operation cancelled by user confirmation failure." -Type "Information"
    exit
}

Show-Message "Confirmation received. Proceeding..." -Type "Success"

# --- Step 3: Offer to Export ---
Show-Message @"

=====================================================================
BACKUP OPTION
=====================================================================
Would you like to export the '$selectedDistro' distribution as a
backup .tar file BEFORE uninstallation?

This is HIGHLY recommended to prevent permanent data loss.

If you choose 'Yes', you will be prompted for an export location.
=====================================================================
"@ -Type "Warning"

$exportChoice = Read-Host "Export '$selectedDistro'? (Yes/No)"

if ($exportChoice -match '^[Yy].*') {
    # Ensure backup directory exists
    if (-not (Test-Path -Path $ExportBackupDirectory)) {
        try {
            New-Item -Path $ExportBackupDirectory -ItemType Directory | Out-Null
            Show-Message "Created backup directory: $ExportBackupDirectory" -Type "Information"
        } catch {
            Show-Message "Could not create backup directory '$ExportBackupDirectory'. $($_.Exception.Message)" -Type "Error"
            $ExportBackupDirectory = Read-Host "Please provide an alternative path to save the backup file"
            if (-not (Test-Path -Path $ExportBackupDirectory)) {
                 Show-Message "The provided path '$ExportBackupDirectory' does not exist. Skipping export." -Type "Warning"
                 $performExport = $false
            } else {
                $performExport = $true
            }
        }
    } else {
         $performExport = $true
         Show-Message "Using backup directory: $ExportBackupDirectory" -Type "Information"
    }

    if($performExport) {
        $exportFileName = "$ExportBackupDirectory\$selectedDistro-backup-$(Get-Date -Format "yyyyMMdd-HHmmss").tar"
        Show-Message "Exporting '$selectedDistro' to '$exportFileName'..." -Type "Information"
        try {
            # Export the distribution
            & wsl.exe --export $selectedDistro $exportFileName
            if ($LASTEXITCODE -eq 0) {
                Show-Message "Export completed successfully." -Type "Success"
                Show-Message "Backup file saved to: $exportFileName" -Type "Information"
            } else {
                Show-Message "Export failed with exit code $LASTEXITCODE." -Type "Error"
                 Show-Message "Continuing may result in irreversible data loss if the export did not succeed." -Type "Warning"
            }
        } catch {
            Show-Message "An error occurred during export: $($_.Exception.Message)" -Type "Error"
            Show-Message "Continuing may result in irreversible data loss if the export did not succeed." -Type "Warning"
        }
    }
} else {
    Show-Message "Skipping export based on user choice." -Type "Information"
    Show-Message "Proceeding without a recent backup WILL result in permanent data loss upon unregistration." -Type "Warning"
}

# --- Step 4: Terminate and Aggressive Confirmation 2 (Wipe) ---

Show-Message @"

=====================================================================
FINAL, EXTREMELY AGGRESSIVE CONFIRMATION REQUIRED - DELETION IMMINENT!
=====================================================================
You are about to UNREGISTER the '$selectedDistro' WSL distribution.

This command:
'wsl --unregister $selectedDistro'

WILL PERMANENTLY DELETE ALL data and files associated with this instance.
This action CANNOT BE UNDONE.
If you did not successfully export a backup, your data WILL be lost.

Type the FULL NAME of the distribution ('$selectedDistro') to CONFIRM
the permanent deletion.
Anything else will CANCEL the uninstallation.
=====================================================================
"@ -Type "Error"

$confirmWipe = Read-Host "Enter the FULL NAME of the distribution ('$selectedDistro') to confirm PERMANENT WIPE"

if ($confirmWipe -ne $selectedDistro) {
    Show-Message "Operation cancelled by final confirmation failure. '$confirmWipe' does not match '$selectedDistro'." -Type "Information"
    exit
}

Show-Message "Final confirmation received. Attempting to terminate and unregister '$selectedDistro'..." -Type "Success"

# Terminate the instance first (optional but recommended)
Show-Message "Attempting to terminate '$selectedDistro'..." -Type "Information"
try {
    & wsl.exe --terminate $selectedDistro
     # Check if the terminate command itself failed (not whether the distro was running)
     if ($LASTEXITCODE -ne 0) {
         # If exit code is non-zero, it might mean the distro wasn't running,
         # or there was an actual error. We'll proceed cautiously.
         Show-Message "Terminate command returned exit code $LASTEXITCODE. This might mean the distro was not running, or an issue occurred." -Type "Warning"
     } else {
          Show-Message "'$selectedDistro' terminated successfully (or was not running)." -Type "Success"
     }

} catch {
    Show-Message "An error occurred during termination: $($_.Exception.Message)" -Type "Warning"
     Show-Message "Attempting to unregister anyway..." -Type "Warning"
}


# Unregister (Wipe) the instance
Show-Message "Attempting to unregister (WIPE) '$selectedDistro'..." -Type "Information"
try {
    & wsl.exe --unregister $selectedDistro
    if ($LASTEXITCODE -eq 0) {
        Show-Message "Successfully unregistered and wiped '$selectedDistro'." -Type "Success"
    } else {
         Show-Message "Failed to unregister '$selectedDistro'. WSL command returned exit code $LASTEXITCODE." -Type "Error"
         Show-Message "The distribution might still be listed but is likely in a bad state." -Type "Error"
         exit 1 # Exit script on critical failure
    }
} catch {
    Show-Message "An error occurred during unregistration (WIPE): $($_.Exception.Message)" -Type "Error"
     Show-Message "The distribution might not have been completely removed." -Type "Error"
    exit 1 # Exit script on critical failure
}

# --- Step 5: Offer to Reinstall ---
Show-Message @"

=====================================================================
REINSTALL OPTION
=====================================================================
The distribution '$selectedDistro' has been successfully removed.

Would you like to install a new, clean WSL distribution now?
=====================================================================
"@ -Type "Information"

$reinstallChoice = Read-Host "Install a new distribution? (Yes/No)"

if ($reinstallChoice -match '^[Yy].*') {
    $onlineDistros = Get-OnlineWslDistributions

    if (-not $onlineDistros) {
        Show-Message "Could not fetch list of available online distributions." -Type "Error"
        Show-Message "You can install manually later using 'wsl --install <DistroName>'." -Type "Information"
    } else {
        Show-Message "Available distributions for installation:" -Type "Information"
        for ($i = 0; $i -lt $onlineDistros.Length; $i++) {
            Write-Host "$($i + 1). $($onlineDistros[$i])"
        }

        $installDistro = $null
        $installDistroIndex = -1

        while ($installDistro -eq $null) {
            $inputChoice = Read-Host "Enter the number of the distribution to install, or 's' to skip"
             if ($inputChoice -ceq 's') {
                 Show-Message "Skipping new distribution installation." -Type "Information"
                 break # Exit the reinstall selection loop
             }

            if ($inputChoice -match '^\d+$') {
                $installDistroIndex = [int]$inputChoice - 1
                if ($installDistroIndex -ge 0 -and $installDistroIndex -lt $onlineDistros.Length) {
                    $installDistro = $onlineDistros[$installDistroIndex]
                } else {
                    Show-Message "Invalid number. Please enter a number from the list or 's'." -Type "Warning"
                }
            } else {
                Show-Message "Invalid input. Please enter a number or 's'." -Type "Warning"
            }
        }

        if ($installDistro) {
             Show-Message "Attempting to install '$installDistro'..." -Type "Information"
            try {
                & wsl.exe --install $installDistro
                 if ($LASTEXITCODE -eq 0) {
                     Show-Message "Installation of '$installDistro' completed successfully." -Type "Success"
                     Show-Message "You may need to complete initial user setup within the new instance." -Type "Information"
                 } else {
                      Show-Message "Installation of '$installDistro' failed with exit code $LASTEXITCODE." -Type "Error"
                 }
            } catch {
                 Show-Message "An error occurred during installation: $($_.Exception.Message)" -Type "Error"
            }
        }
    }
} else {
    Show-Message "Skipping new distribution installation." -Type "Information"
}

Show-Message @"

Script finished.
The selected distribution has been processed.
"$selectedDistro" should no longer be listed by 'wsl --list'.
"@ -Type "Information"
