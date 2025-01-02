#!/bin/bash

echo "Create single GPT ext4 partition on sdc1, then mount at /mnt/nfs-share"

# 1st option warns and exits, 2nd auto-elevates with sudo if not running as root
# if [ "$(id -u)" -ne 0 ]; then echo "This script must be run as root or with sudo" 1>&2; exit 1; fi
if [ "$(id -u)" -ne 0 ]; then echo -e "\033[31mElevation required; rerunning as sudo...\033[0m"; sudo "$0" "$@"; exit 0; fi

# Define device and mount point
DEVICE="/dev/sdc"
MOUNT_POINT="/mnt/nfs-share/sdc1"
PARTITION="${DEVICE}1"

# Step 1: Create GPT partition table using parted (automated, non-interactive)
parted $DEVICE --script mklabel gpt

# Step 2: Create the partition
parted $DEVICE --script mkpart primary ext4 0% 100%

# Step 3: Format the partition with ext4
mkfs.ext4 $PARTITION

# Step 4: Create the mount point directory
mkdir -p $MOUNT_POINT
# [ ! -d /mnt/nfs-share ] && mkdir -p /mnt/nfs-share

# Step 5: Mount the partition
mount $PARTITION $MOUNT_POINT

# Step 6: Add to /etc/fstab for persistence
echo "$PARTITION $MOUNT_POINT ext4 defaults 0 0" >> /etc/fstab

# Step 7: Confirm everything is set up
echo "Partition $PARTITION has been created, formatted, and mounted at $MOUNT_POINT."
echo "Entry added to /etc/fstab for persistence."
echo "your fstab has been modified, but systemd still uses the old version; use 'systemctl daemon-reload' to reload."
