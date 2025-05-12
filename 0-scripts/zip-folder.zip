#!/bin/bash
set -e

# Functions for colored output
green()  { echo -e "\033[1;32m$*\033[0m"; }
white()  { echo -e "\033[0;37m$*"; }
red()    { echo -e "\033[1;31m$*\033[0m"; }

# Check for zip dependency
if ! command -v zip &>/dev/null; then
    red "Error: 'zip' command not found. Please install it first."
    exit 1
fi

# Ensure exactly one argument is provided
if [ "$#" -ne 1 ]; then
    white "Usage: $0 /full/path/to/folder"
    white "  - Must be a directory (not a file)"
    white "  - Recursively backs up with hidden files/folders included"
    white "  - Backup saved to ~/.backup-quick/<folder>-YYYY-MM-DD_HH-MM-SS.zip"
    exit 1
fi

SRC="$1"

# Check if input is a directory
if [ ! -d "$SRC" ]; then
    red "Error: '$SRC' is not a directory."
    exit 1
fi

# Prepare paths and names
SRC_ABS="$(realpath "$SRC")"
FOLDER_NAME="$(basename "$SRC_ABS")"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
DEST_DIR="$HOME/.backup-quick"
ZIP_NAME="${FOLDER_NAME}-${TIMESTAMP}.zip"
ZIP_PATH="${DEST_DIR}/${ZIP_NAME}"

# Create backup directory if needed
mkdir -p "$DEST_DIR"

# Calculate source size in MB
SRC_SIZE=$(du -sm "$SRC_ABS" | awk '{printf "%.2f", $1/1}')

# Show full command to be run
green "\$ zip -r -9 \"$ZIP_PATH\" \"$FOLDER_NAME\""

# Move to folder's parent for clean zipping
cd "$(dirname "$SRC_ABS")"

# Run zip quietly
zip -r -9 "$ZIP_PATH" "$FOLDER_NAME" >/dev/null

# Get final zip size
ZIP_SIZE=$(du -sm "$ZIP_PATH" | awk '{printf "%.2f", $1/1}')

# Output result
white "Creating backup for: $SRC_ABS   (size: ${SRC_SIZE} MB)"
white "Destination zip:     $ZIP_PATH   (size: ${ZIP_SIZE} MB)"
white "✅ Backup complete!"

