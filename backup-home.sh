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

# Define exclusions with explanations
excludes=(
    # Exclude the backup-home directory as it is the target of the backup
    "--exclude='backup-home/'"
    # .cache (contains temporary cache files)
    "--exclude='.cache/'"
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
done <<< "$mountedShares"A

# Injecting ${excludes[@]} directly to the rsync command always ignored all excludes, even though
# printing the command showed the correct syntax *and* running that command worked.
# As a workaround, expand the array to a string and ensure that it is a string before injecting.

# Expand the array into a single string then trim leading/trailing spaces and replace multiple spaces with a single space
excludesStr=$(printf " %s" "${excludes[@]}")
excludesStr=$(echo "$excludesStr" | tr -s ' ')

# Construct the rsync commands with the formatted exclusions
rsyncFull="rsync -avi --checksum $excludesStr \"$HOME/\" \"$backupPath\""
rsyncIncremental="rsync -avi --checksum --link-dest=\"$lastBackup\" $excludesStr \"$HOME/\" \"$backupPath\""

# Print the constructed rsync command for debugging
echo "Debug: $rsyncCommand"

# Run the rsync command
# copiedItems=$(eval $rsyncCommand | tee /dev/tty)



# Perform backup
if [ -z "$lastBackup" ]; then
  backupType="Full"
  echo "$dateTime No previous backup found. Performing a full backup..."
  echo "$dateTime $backupType backup started." >> "$logFile"
  echo "Debug: $rsyncFull"
  # exit 1
  copiedItems=$(eval $rsyncFull | tee /dev/tty)
  # copiedItems=$(rsync -avi --checksum ${excludes[@]} "$HOME/" "$backupPath")
else
  backupType="Incremental"
  echo "$dateTime Performing an incremental backup using hard links..."
  echo "$dateTime $backupType started." >> "$logFile"
  echo "Debug: $rsyncIncremental"
  # exit 1
  copiedItems=$(eval $rsyncIncremental | tee /dev/tty)
  # copiedItems=$(rsync -avi --checksum --link-dest="$lastBackup" ${excludes[@]} "$HOME/" "$backupPath")
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
    (crontab -l 2>/dev/null; echo "0 * * * * $scriptCron") | crontab -
    echo "$scriptCron added to cron to run every hour on the hour."
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
