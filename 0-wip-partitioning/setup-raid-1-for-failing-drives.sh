#!/bin/bash

set -e

RAID_DEV="/dev/md0"
DISK1="/dev/sdb"
DISK2="/dev/sdd"
MOUNT_POINT="/mnt/raid1"
FS_TYPE="ext4"

# Ensure mdadm is installed
echo "Installing mdadm..."
sudo apt update && sudo apt install -y mdadm

# Ensure the drives are not mounted
echo "Unmounting $DISK1 and $DISK2 if mounted..."
sudo umount $DISK1 || true
sudo umount $DISK2 || true

# Clear any previous RAID metadata
echo "Wiping old RAID metadata..."
sudo mdadm --zero-superblock --force $DISK1 $DISK2

# Create RAID 1 array
echo "Creating RAID 1 array..."
sudo mdadm --create --verbose $RAID_DEV --level=1 --raid-devices=2 $DISK1 $DISK2 --metadata=1.2

# Wait for RAID sync
echo "Waiting for RAID sync to start..."
sleep 5
cat /proc/mdstat

# Format the RAID device
echo "Formatting RAID device as $FS_TYPE..."
sudo mkfs.$FS_TYPE $RAID_DEV

# Create mount point
echo "Creating mount point at $MOUNT_POINT..."
sudo mkdir -p $MOUNT_POINT

# Mount the RAID array
echo "Mounting RAID array..."
sudo mount $RAID_DEV $MOUNT_POINT

# Get UUID
UUID=$(blkid -s UUID -o value $RAID_DEV)

# Add to fstab for persistence
echo "Adding RAID array to /etc/fstab..."
echo "UUID=$UUID $MOUNT_POINT $FS_TYPE defaults,nofail 0 2" | sudo tee -a /etc/fstab

# Save RAID configuration
echo "Saving RAID configuration..."
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
sudo update-initramfs -u

echo "RAID 1 setup complete. Check status with: cat /proc/mdstat"

