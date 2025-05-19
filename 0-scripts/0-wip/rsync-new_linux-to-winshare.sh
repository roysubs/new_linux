#!/bin/bash

# Task: replicate a folder from Debian system to a shared Windows folder mounted on CIFS
# Note: This is a very dangerous operation as it will overwrite and delete files/folders that do not match the source!

SOURCE_DIR="$HOME/new_linux/"
SHARE_DIR="$HOME/192.168.1.29-d"
TARGET_DIR="$SHARE_DIR/new_linux/"

# Dry run command to show what will be done
echo
echo "Custom backup of '$SOURCE_DIR' to '$TARGET_DIR' on Windows share."
echo "Using a static script for this as rsync with --delete can remove everything at the target side."
echo
echo "Dry run: The following command will just sanity check the file transfer."
echo "rsync -av --dry-run --delete '$SOURCE_DIR' '$TARGET_DIR'"
echo
read -p "Do you want to continue with the dry run? (y/n): " dry_run_choice

if [[ "$dry_run_choice" != "y" ]]; then
    echo "Dry run aborted."
    exit 1
fi

# Dry run (will show what would happen without making changes)
rsync -av --dry-run --delete "$SOURCE_DIR" "$TARGET_DIR"

# Full run confirmation
echo
echo
echo "Full run: The following command will perform the actual file transfer."
echo "rsync -av --delete '$SOURCE_DIR' '$TARGET_DIR'"
echo
echo

# Check if source exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Source dir    '$SOURCE_DIR' does not exist. Exiting."
    exit 1
else
    echo "Source dir    '$SOURCE_DIR' exists."
fi

# Check if destination exists
if mountpoint -q $HOME/192.168.1.29-d; then
    echo "Windows share '~/192.168.1.29-d' exists and is mounted."
else
    echo "The Windows share is not mounted. Exiting."
    exit 1
fi

if [ -d $TARGET_DIR ]; then
    echo "Target dir    '$TARGET_DIR' exists, rsync will overwrite files in this folder."
    echo
    echo -e "\033[0;31mWARNING: Files and directories will be overwritten and deleted if they are not present in the source.\033[0m"
    read -p "Are you sure you want to continue (type 'continue' to proceed): " confirmation
    if [[ "$confirmation" != "continue" ]]; then
        echo "Operation aborted."
        exit 1
    fi
else 
    echo "Target dir    '$TARGET_DIR' does not exist yet, so it is safe to continue."
fi

# SMB Version Compatibility note
echo -e "
Note: Rsync interprets the path literally. If 'new_linux' does not already
exist on the destination, rsync won't create it unless the parent directories
are accessible."
echo -e "
Rsync works across SMB shares. The option 'vers=3.0' ensures SMB 3.0 is used,
but not all servers fully support it. If the share behaves oddly, try vers=2.0
or vers=1.0 as a test."
echo -e "
If the folder is not being created, you can try the --mkpath option with rsync
to try and force creation of the directories along the destination path."

# Offer to run rsync with strace
echo
read -p "Would you like to run rsync with strace to trace system calls and debug directory creation? (y/n): " strace_choice
if [[ "$strace_choice" == "y" ]]; then
    echo "Running strace command to trace system calls:"
    echo "strace rsync -av --delete '$SOURCE_DIR' '$TARGET_DIR'"
    sudo apt install strace -y
    strace rsync -av --delete "$SOURCE_DIR" "$TARGET_DIR"
else
    rsync -av --delete "$SOURCE_DIR" "$TARGET_DIR"
fi

echo
echo "Rsync operation completed."

