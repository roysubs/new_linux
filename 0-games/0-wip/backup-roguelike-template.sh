#!/bin/bash

# --- Configuration ---
# !! IMPORTANT: Replace with the actual path to your game's save file !!
# You might need to find the exact save file name as well.
SAVE_FILE="/home/yourusername/.config/dcss/saves/yourplayername.sav"

# !! IMPORTANT: Replace with the path to your desired backup directory !!
BACKUP_DIR="/home/yourusername/roguelike_saves_backup"

# Backup interval in seconds (e.g., 300 seconds = 5 minutes)
BACKUP_INTERVAL=300

# --- Script Logic ---

echo "Starting automatic backup script for ${SAVE_FILE}"
echo "Backups will be saved to ${BACKUP_DIR} every ${BACKUP_INTERVAL} seconds."
echo "Press Ctrl+C to stop the script."

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

while true; do
    # Check if the save file exists before trying to copy
    if [ -f "$SAVE_FILE" ]; then
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        BACKUP_FILE="${BACKUP_DIR}/$(basename "$SAVE_FILE").${TIMESTAMP}"

        # Copy the save file
        cp "$SAVE_FILE" "$BACKUP_FILE"

        if [ $? -eq 0 ]; then
            echo "Backed up ${SAVE_FILE} to ${BACKUP_FILE}"
        else
            echo "Error backing up ${SAVE_FILE}" >&2 # Output errors to stderr
        fi
    else
        # Commenting this out as the file might not exist before the first save in game
        # echo "Save file ${SAVE_FILE} not found."
        : # Do nothing if save file doesn't exist yet
    fi

    # Wait for the next interval
    sleep "$BACKUP_INTERVAL"
done
