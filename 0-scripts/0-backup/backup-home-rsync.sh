#!/bin/bash

####################
#
# Safely Backup $HOME to $HOME/backup-home with rsync.
# Backing up $HOME as a subfolder of $HOME means no issues with TimeShift
# Must exclude $HOME/backup-home and any dynamically created mounts / shares
# All backups are full but use space like incremental as they use (hard link inodes).
# As inodes, any older backups can be deleted as every backup contains all required information.
# The script will copy itself into $HOME/backup-home and setup an hourly cron.
#
####################

backupDir="$HOME/backup-home"
dateTime=$(date +"%Y-%m-%d_%H-%M-%S")
logFile="$backupDir/backup-log.txt"

# Ensure backup directory exists
mkdir -p "$backupDir"
backupPath="$backupDir/$dateTime"

# Find the most recent backup directory, excluding the current backupPath
lastBackup=$(find "$backupDir" -mindepth 1 -maxdepth 1 -type d | grep -v "$backupPath" | sort | tail -n 1)
# lastBackup=$(find "$backupDir" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)

# Define exclusions; note that descriptions cannot be on same line as the exclude
excludes=(
    # Exclude the backup-home directory as it is the target of the backup
    "--exclude='backup-home/'"
    # .cache (contains temporary cache files)
    "--exclude='.cache/'"
    # nvim shada folder is volatile session state data
    "--exclude='.local/state/nvim'"
    # .mozilla (contains browser data that can be recreated)
    "--exclude='.mozilla/'"
    # .local/share/Trash (Trash folder)
    "--exclude='.local/share/Trash/'"
    # .Trash (other possible Trash location)
    # "--exclude='.Trash/'"
    # .gvfs (virtual filesystem directory)
    # "--exclude='.gvfs/'"
    # .thumbnails (image/video cache)
    # "--exclude='.thumbnails/'"
)

# Exclude any dynamically mounted shares in the home folder
# And convert them to *relative* paths as rsync will ignore full paths
mountedShares=$(findmnt -r -o TARGET -t cifs,nfs,sshfs,ext4 | grep "^$HOME" | sed "s|^$HOME/||")
while IFS= read -r share; do
    if [[ -n "$share" ]]; then  # Only add non-empty shares
        excludes+=("--exclude='$share/'")
    fi
done <<< "$mountedShares"

# Injecting ${excludes[@]} directly to the rsync command always ignored all excludes, even though
# printing the command showed the correct syntax *and* running that command worked.
# As a workaround, expand the array to a string and ensure that it is a string before injecting.

# Expand the array into a single string then trim leading/trailing spaces and replace multiple spaces with a single space
excludesStr=$(printf " %s" "${excludes[@]}")
excludesStr=$(echo "$excludesStr" | tr -s ' ')

# Construct the rsync commands with the formatted exclusions
rsyncFull="rsync -a $excludesStr \"$HOME/\" \"$backupPath\""   # --checksum
rsyncIncremental="rsync -a --link-dest=\"$lastBackup\" $excludesStr \"$HOME/\" \"$backupPath\""

# Run the rsync command
# copiedItems=$(eval $rsyncCommand | tee /dev/tty)

# Perform backup
if [ -z "$lastBackup" ]; then
  backupType="Full"
  echo "$dateTime No previous backup found. Performing a full backup..."
  echo "$dateTime $backupType backup started." >> "$logFile"
  echo -e "Full command:\n$rsyncFull"
  copiedItems=$(eval $rsyncFull | tee /dev/tty)
else
  backupType="Incremental"
  echo "$dateTime Performing an incremental backup using hard links..."
  echo "$dateTime $backupType started." >> "$logFile"
  echo -e "Full command:\n$rsyncIncremental"
  copiedItems=$(eval $rsyncIncremental | tee /dev/tty)
fi

# # After backup, use rsync --dry-run to compare the backup
# echo "$dateTime Comparing the latest backup with the previous one..."
# if rsync -avi --dry-run --checksum --link-dest="$lastBackup" $excludesStr "$HOME/" "$backupPath" | grep -q "^"; then
#     echo "$dateTime The latest backup contains changes so will be kept." >> "$logFile"
# else
#     echo "$dateTime The latest backup is identical to the previous one. Deleting redundant backup..."
#     rm -rf "$backupPath"
#     echo "$dateTime Redundant backup deleted." >> "$logFile"
# fi

compare_backups() {
    local previous="$1"
    local current="$2"

    # Compare using rsync dry-run
    rsync --dry-run --checksum -avi "$previous/" "$current/" | grep -q "^>" || return 0  # Identical
    return 1  # Changes detected
}

if compare_backups "$lastBackup" "$newBackup"; then
    echo "No changes detected. Removing redundant backup: $newBackup"
    rm -rf "$newBackup"
else
    echo "The latest backup contains changes so will be kept."
fi

# Calculate the size of the backup
copiedFilesSize=0
copiedFilesNum=0

if [ "$backupType" == "Full" ]; then
  backupSize=$(du -sh "$backupPath" | cut -f1)
  copiedFilesNum=$(echo "$copiedItems" | grep '^>' | wc -l)
else
  echo "Backup summary (Size | Modified Date | Name):"
  echo "-------------------------------------------------"
  while read -r line; do
    if [[ $line == *">"* ]]; then
      relPath=$(echo "$line" | awk '{print $2}')
      fullPath="$HOME/$relPath"
      if [ -e "$fullPath" ]; then
        size=$(stat --printf="%s" "$fullPath")
        modDate=$(stat --printf="%y" "$fullPath" | cut -d '.' -f 1)      # Remove fractional seconds
        humanReadableSize=$(numfmt --to=iec --suffix=B --format="%.1f" "$size")
        printf "%7s %s %s\n" "$humanReadableSize" "$modDate" "$relPath" | tee -a "$logFile"
        copiedFilesSize=$((copiedFilesSize + size))
        copiedFilesNum=$((copiedFilesNum + 1))
      fi
    fi
  done <<< "$copiedItems"
  echo "-------------------------------------------------"
  backupSize=$(numfmt --to=iec --suffix=B --format="%.1f" "$copiedFilesSize")
fi

# Update dateTime and print completion message to console and to log file
dateTime=$(date +"%Y-%m-%d_%H-%M-%S")
completionMessage="$dateTime $backupType complete. $copiedFilesNum files were copied. $backupSize was backed up."
echo "$completionMessage" | tee -a "$logFile"
echo "-------------------------------------------------"

####################
#
# Set this script to run every hour in cron
# As backups are incremental with hard links, space usage will normally be small
#
####################

scriptPath="$(realpath "$0")"          # Get full path of this script
scriptName="$(basename "$scriptPath")" # Just the name
scriptCron="$backupDir/$scriptName"    # The working script that cron calls will reside in the backup_home folder
cp $scriptPath $scriptCron
cronJobExists=$(crontab -l 2>/dev/null | grep -F "$scriptCron")   # Check if the cron job already exists

# if the job is already in cron, then nothing will happen.
# if the job is not in cron, first, get all entries "crontab -l", then add the new entry, then pipe to "crontab -"
if [[ -z "$cronJobExists" ]]; then
    (crontab -l 2>/dev/null; echo "*/5 * * * * $scriptCron") | crontab -  # Every 5 minutes
    # (crontab -l 2>/dev/null; echo "*/10 * * * * $scriptCron") | crontab - # Every 10 minutes
    # (crontab -l 2>/dev/null; echo "0 * * * * $scriptCron") | crontab -    # Every hour
    echo "$scriptCron added to cron:"
    crontab -l
else
    echo "$scriptCron already exists in cron."
fi

# In cron, the syntax "0 * * * *" means:
# 0 in the minute field: Execute at minute 0 (the start of the hour).
# * in the hour field: Any hour (0-23).
# * in the day of month field: Any day of the month (1-31).
# * in the month field: Any month (1-12).
# * in the day of the week field: Any day of the week (0-7, where both 0 and 7 represent Sunday).
# crontab -e   # Edit the crontab in a text editor; to disable a specific job, comment it out with #
# crontab -l   # Displays all scheduled jobs for the current user.
# crontab -r   # remove all cron jobs
# User cron jobs are stored in /var/spool/cron/crontabs/<username> (do not ever touch these)
# sudo systemctl stop cron   # Stop cron (until next reboot
# sudo systemctl start cron  # Start cron
# cat /etc/crontab           # List system-wide cron jobs

####################
# Prune old backups (only runs on Sunday at midnight)
####################

if [[ "$(date +%u)" -eq 7 && "$(date +%H)" -eq 0 ]]; then
    echo "It's Sunday midnight. Pruning old backups..." | tee -a "$logFile"

    # Find all backups older than 14 days
    oldBackups=$(find "$backupDir" -mindepth 1 -maxdepth 1 -type d -mtime +14 | sort)

    declare -A sundayBackups
    
    for backup in $oldBackups; do
        backupName=$(basename "$backup")

        # Extract the timestamp from the backup name
        backupTime=$(echo "$backupName" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}")
        backupDate=${backupTime:0:10}  # Extract YYYY-MM-DD
        backupHourMin=${backupTime:11:5}  # Extract HH-MM

        # Check if this backup is a Sunday backup
        backupDay=$(date -d "$backupDate" +%u)
        
        if [[ "$backupDay" -eq 7 ]]; then
            # Store Sunday backups with the key as date and value as closest time to midnight
            if [[ -z "${sundayBackups[$backupDate]}" || "$backupHourMin" < "${sundayBackups[$backupDate]}" ]]; then
                sundayBackups[$backupDate]="$backupHourMin"
            fi
        fi
    done

    for backup in $oldBackups; do
        backupName=$(basename "$backup")
        backupTime=$(echo "$backupName" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}")
        backupDate=${backupTime:0:10}
        backupHourMin=${backupTime:11:5}

        # If this is the closest Sunday midnight backup, keep it
        if [[ "${sundayBackups[$backupDate]}" == "$backupHourMin" ]]; then
            echo "Keeping closest Sunday midnight backup: $backupName" | tee -a "$logFile"
        else
            echo "Deleting old backup: $backupName" | tee -a "$logFile"
            rm -rf "$backup"
        fi
    done
fi

