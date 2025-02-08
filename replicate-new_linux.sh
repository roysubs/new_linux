#!/bin/bash

# Create a mirror replica of ~/new_linux to ~/new_linux_bak.
# This will overwrite anything in ~/new_linux_bak as it syncs
# that folder to match ~/new_linux
# Useful for when doing possible breaking changes to have a quick
# local restore available, and for rsync syntax.

# Source and destination directories
SRC_DIR=~/new_linux/
DST_DIR=~/new_linux_bak/

# rsync command with --delete to make DEST_DIR a replica of SOURCE_DIR
rsync -avh --delete "$SRC_DIR" "$DST_DIR"

# Check if rsync succeeded
if [ $? -eq 0 ]; then
    echo "Replication completed successfully. '$DST_DIR' is now a replica of '$SRC_DIR'."
else
    echo "Error: Replication failed."
    exit 1
fi

