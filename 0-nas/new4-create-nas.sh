#!/bin/bash

# Script to create mount points, mount devices, and share them via Samba.
# Excludes small partitions, unformatted partitions, and swap.

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo "$0" "$@"
fi

set -e

# Backup existing Samba configuration
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SMB_CONF="/etc/samba/smb.conf"
SMB_BACKUP="${SMB_CONF}.${TIMESTAMP}.bak"
echo "Backing up Samba configuration to $SMB_BACKUP..."
cp "$SMB_CONF" "$SMB_BACKUP"

# Function to display and run a command
echo_and_run() {
    echo "$1"
    eval "$1"
}

# Threshold to ignore small partitions (in bytes)
MIN_SIZE=$((1024 * 1024 * 1024)) # 1GB in bytes

# Base mount point directory
BASE_MOUNT_DIR="/mnt"

# Get block devices and filter valid partitions
PARTITIONS=$(lsblk -lnpo NAME,TYPE,FSTYPE,MOUNTPOINT,SIZE,UUID | awk \
'/part/ && $3 != "" && $4 == "" { 
    size_bytes=0;
    split($5, size, /[A-Za-z]+/);
    unit = substr($5, length(size[1]) + 1);
    if (unit == "B") size_bytes = size[1];
    else if (unit == "K") size_bytes = size[1] * 1024;
    else if (unit == "M") size_bytes = size[1] * 1024 * 1024;
    else if (unit == "G") size_bytes = size[1] * 1024 * 1024 * 1024;
    else if (unit == "T") size_bytes = size[1] * 1024 * 1024 * 1024 * 1024;
    if (size_bytes >= '$MIN_SIZE') print $1, $5, $6;
}')

# Debug: Print the output of PARTITIONS
echo "PARTITIONS: $PARTITIONS"

echo
echo $PARTITIONS
echo

if [[ -z "$PARTITIONS" ]]; then
    echo "No valid partitions found to mount and share. Exiting."
    exit 0
fi

# Counter for share naming
SHARE_COUNT=0

# Process each partition
while read -r DEVICE SIZE UUID; do
    SHARE_COUNT=$((SHARE_COUNT + 1))

    # Convert size to human-readable format (e.g., 0.4TB, 1.8TB)
    SIZE_HR=$(echo "$SIZE" | awk '{
        split("B KB MB GB TB", units, " ");
        for (i=5; $1 >= 1024 && i > 1; i--) $1 /= 1024;
        printf "%.1f%s", $1, units[i]
    }')

    # Generate mount point and share name
    MOUNT_POINT="$BASE_MOUNT_DIR/$(basename "$DEVICE")"
    SHARE_NAME="NAS${SHARE_COUNT}-${SIZE_HR}"

    # Create mount point if it doesn't exist
    if [[ ! -d "$MOUNT_POINT" ]]; then
        echo_and_run "sudo mkdir -p $MOUNT_POINT"
    fi

    # Mount the partition if not already mounted
    echo_and_run "sudo mount $DEVICE $MOUNT_POINT"

    # Add Samba share configuration
    SMB_ENTRY="[$SHARE_NAME]\n   path = $MOUNT_POINT\n   browseable = yes\n   read only = no\n   guest ok = yes\n   force user = nobody\n   create mask = 0777\n   directory mask = 0777"

    if ! grep -q "\[$SHARE_NAME\]" "$SMB_CONF"; then
        echo "Adding Samba share for $DEVICE at $MOUNT_POINT..."
        echo -e "$SMB_ENTRY" | sudo tee -a "$SMB_CONF" > /dev/null
    else
        echo "Samba share for $DEVICE already exists. Skipping."
    fi

done <<< "$PARTITIONS"

# Restart Samba services
echo_and_run "sudo systemctl restart smbd"
echo_and_run "sudo systemctl restart nmbd"

# Completion message
echo "Configuration complete. Access shares using \\\\<server-ip>\\<share-name>."

