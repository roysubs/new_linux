#!/bin/bash

# Create a replica of /new_linux at /new_linu_bak
# Useful for when doing possible breaking changes to have a quick
# local restore available, and for rsync syntax.

# Source and destination directories
SOURCE_DIR=~/new_linux/
DEST_DIR=~/new_linux_bak/

# rsync command with --delete to make DEST_DIR a replica of SOURCE_DIR
rsync -avh --delete "$SOURCE_DIR" "$DEST_DIR"

# Check if rsync succeeded
if [ $? -eq 0 ]; then
    echo "Replication completed successfully. '$DEST_DIR' is now a replica of '$SOURCE_DIR'."
else
    echo "Error: Replication failed."
    exit 1
fi

