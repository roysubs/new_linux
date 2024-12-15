#!/bin/bash

echo "Unmount and destroy /dev/sdc1"

# 1st option warns and exits, 2nd auto-elevates with sudo if not running as root
# if [ "$(id -u)" -ne 0 ]; then echo "This script must be run as root or with sudo" 1>&2; exit 1; fi
if [ "$(id -u)" -ne 0 ]; then echo -e "\033[31mElevation required; rerunning as sudo...\033[0m"; sudo "$0" "$@"; exit 0; fi

# Define device and mount point
DEVICE="/dev/sdc"
MOUNT_POINT="/mnt/nfs-share/sdc1"
PARTITION="${DEVICE}1"

# Step 1: Confirmation prompt to destroy the partition and mount point
echo "WARNING: This will destroy the partition $PARTITION, unmount it, remove it from /etc/fstab, and delete the partition. Proceed only if you are sure!"
read -p "Are you sure you want to continue? (y/N): " confirmation

if [[ "$confirmation" != "y" && "$confirmation" != "Y" ]]; then
    echo "Operation aborted. No changes have been made."
    exit 0
fi

# Step 2: Unmount the partition
echo "Unmounting $MOUNT_POINT..."
umount $MOUNT_POINT

# Step 3: Remove the entry from /etc/fstab
echo "Removing $PARTITION from /etc/fstab..."
sed -i "\|$PARTITION|d" /etc/fstab

# Step 4: Delete the partition using parted (non-interactive)
echo "Deleting the partition $PARTITION..."
parted $DEVICE --script rm 1

# Step 5: Optionally, delete the partition's filesystem (optional but ensures complete destruction)
echo "Zeroing the partition table (optional but recommended)..."
dd if=/dev/zero of=$DEVICE bs=512 count=1 conv=notrunc

# Step 6: Confirm the destruction
echo "Partition $PARTITION has been destroyed, unmounted, and removed from /etc/fstab."

