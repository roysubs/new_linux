#!/bin/bash

# Define variables
BACKUP_DIR="$HOME/backup-fs"
SCRIPT_NAME="$(basename "$0")"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUTPUT_FILE="$BACKUP_DIR/home-boss_$TIMESTAMP.txt"
IGNORE_LIST=("." ".." "backup-home" "backup-fs" ".cache" "Trash")

# Create the backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Derive the home directory name
HOME_NAME=$(realpath ~ | sed 's/.*\///')

# Build the ignore patterns for ls
IGNORE_PATTERNS=()
for dir in "${IGNORE_LIST[@]}"; do
    IGNORE_PATTERNS+=("--ignore=$dir")
done

# Time the command and save the snapshot
{
    # Perform ls with ignore patterns and capture output
    # -A includes hidden files but excludes . and ..
    # Note that "total" is the total size in 1K blocks
    time ls -lAR "$HOME" "${IGNORE_PATTERNS[@]}" --time-style="+%Y-%m-%d %H:%M:%S" > "$OUTPUT_FILE"
    # | grep -v "^$(echo ~/backup-home | sed 's/[][\.*^$]/\\&/g')$" > "$OUTPUT_FILE"
} 2>&1 | tee -a "$OUTPUT_FILE"

# Copy the script itself to the backup folder
cp "$0" "$BACKUP_DIR/$SCRIPT_NAME"

# Add a cron job to run this script daily at 00:01
(crontab -l 2>/dev/null; echo "1 0 * * * $HOME/$SCRIPT_NAME") | crontab -

# End of script

