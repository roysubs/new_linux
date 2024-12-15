#!/bin/bash

# Ensure the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[0;31mThis script must be run as root\033[0m" 
    exit 1
fi

# Check if device argument is provided
if [ -z "$1" ]; then
    echo -e "\033[0;31mUsage: $0 /dev/sdX\033[0m"
    exit 1
fi

device=$1

# Step 0: Display the current disk layout using lsblk
echo "Step 0: Displaying current disk layout using lsblk"
lsblk

# Step 1: Check for Samba shares on the device
echo "Step 1: Samba Shares on partitions of $device"
samba_shares=$(smbclient -L localhost -U% | grep -i "$device")
if [ -z "$samba_shares" ]; then
    echo "No Samba shares found for this device."
else
    echo "Samba shares found:"
    echo "$samba_shares"
fi

# Step 2: Check for NFS shares on the device
echo "Step 2: NFS Shares on partitions of $device"
nfs_shares=$(exportfs -v | grep "$device")
if [ -z "$nfs_shares" ]; then
    echo "No NFS shares found for this device."
else
    echo "NFS shares found:"
    echo "$nfs_shares"
fi

# Step 3: Check for mount points associated with the device
echo "Step 3: Mount points associated with $device"
mount_points=$(findmnt -r -o TARGET,SOURCE | grep "$device")
if [ -z "$mount_points" ]; then
    echo "No mount points found for this device."
else
    echo "Mount points found:"
    echo "$mount_points"
fi

# Step 4: List partitions on the device
echo "Step 4: Partitions on $device"
partitions=$(lsblk -lno NAME | grep "^${device//\/dev\//}")
echo "The following partitions are found:"
echo "$partitions"

# Ask the user if they want to remove the partitions
read -p "Do you want to completely remove these partitions? (y/n): " answer
if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
    echo "Exiting script without making changes."
    exit 0
fi

# Removing partitions using parted without interactive prompts
for partition in $partitions; do
    echo "Removing partition: /dev/$partition"
    parted --script "$device" rm "${partition//$device/}"
done

# Step 5: Remove all references to the device in /etc/fstab
echo "Step 5: Removing all references from /etc/fstab"
fstab_entry=$(grep -i "$device" /etc/fstab)
if [ -z "$fstab_entry" ]; then
    echo "No references to $device found in /etc/fstab."
else
    echo "Found the following references to $device in /etc/fstab:"
    echo "$fstab_entry"
    read -p "Do you want to remove all references to $device from /etc/fstab? (y/n): " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        # Corrected sed delimiter usage |d|
        sed -i "#$device#d#" /etc/fstab
        if [ $? -eq 0 ]; then
            echo "References removed from /etc/fstab."
        else
            echo -e "\033[0;31mError removing references from /etc/fstab\033[0m"
        fi
    else
        echo "No changes made to /etc/fstab."
    fi
fi

# Reload systemd to ensure changes take effect
echo "Reloading systemd..."
systemctl daemon-reload

# Final message
echo "Disk $device has been completely stripped down."

