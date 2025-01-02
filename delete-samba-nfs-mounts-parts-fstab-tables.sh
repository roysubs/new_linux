#!/bin/bash

# Function to execute and display commands
run_command() {
    echo -e "\033[34mRunning: $*\033[0m"
    eval "$*"
    if [ $? -ne 0 ]; then
        echo -e "\033[31mCommand failed: $*\033[0m"
        exit 1
    fi
}

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo "$0" "$@"
fi

# Check if device argument is provided
if [ -z "$1" ]; then
    echo -e "Usage: $0 /dev/sdX"
    exit 1
fi

device=$1

# Step 0: Display the current disk layout using lsblk
echo "Step 0: Displaying current disk layout using lsblk"
run_command lsblk

echo
read -p "Do you want to delete all components from $device? (y/n): " answer
if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    echo "Exiting script without making changes."
    exit 0
fi

# Step 1: Check for Samba shares on the device
echo "Step 1: Remove any Samba shares on partitions of $device"
if command -v smbclient &>/dev/null; then
    samba_shares=$(smbclient -L localhost -U% 2>/dev/null | grep -i "$device")
    if [ -z "$samba_shares" ]; then
        echo "No Samba shares found for this device."
    else
        echo "Samba shares found:"
        echo "$samba_shares"
    fi
else
    echo "Samba-related tools are not installed. Skipping this step."
fi

# Step 2: Check for NFS shares on the device
echo "Step 2: Remove any NFS shares on partitions of $device"
if command -v exportfs &>/dev/null; then
    nfs_shares=$(exportfs -v 2>/dev/null | grep "$device")
    if [ -z "$nfs_shares" ]; then
        echo "No NFS shares found for this device."
    else
        echo "NFS shares found:"
        echo "$nfs_shares"
    fi
else
    echo "NFS-related tools are not installed. Skipping this step."
fi

# Step 3: Check for mount points associated with the device
echo "Step 3: Mount points associated with $device"
mount_points=$(findmnt -r -o TARGET,SOURCE | grep "$device")
if [ -z "$mount_points" ]; then
    echo "No mount points found for this device."
else
    echo "Mount points found:"
    echo "$mount_points"
    echo "Unmounting all associated mount points..."
    echo "$mount_points" | awk '{print $1}' | while read -r target; do
        run_command umount "$target"
    done
fi

# Step 4: List and remove partitions on the device
echo "Step 4: Removing partitions from $device"
# Use parted to list partition numbers
partition_numbers=$(parted --script "$device" print | awk '/^ [0-9]+/ {print $1}')

if [ -z "$partition_numbers" ]; then
    echo "No partitions found on $device."
else
    for partition_number in $partition_numbers; do
        echo "Removing partition number: $partition_number from $device"
        run_command parted --script "$device" rm "$partition_number"
    done
fi

# Step 5: Remove all references to the device in /etc/fstab
echo "Step 5: Removing all references from /etc/fstab"
fstab_entry=$(grep -i "$device" /etc/fstab)
if [ -z "$fstab_entry" ]; then
    echo "No references to $device found in /etc/fstab."
else
    echo "Found the following references to $device in /etc/fstab:"
    echo "$fstab_entry"
    # run_command sed -i "\|${device}|d" /etc/fstab
    # Have not been able to get this sed expression to work via run_command
    echo -e "\033[34msed -i \"\|\${device}\|d\" /etc/fstab\033[0m"
    sed -i "\|${device}|d" /etc/fstab
    echo "References removed from /etc/fstab."
fi

# Wipe the partition table after removing all partitions
echo "Step 6: Wiping partition table on $device"
run_command wipefs --all --force "$device"

# Reload systemd to ensure changes take effect
echo "Reloading systemd..."
run_command systemctl daemon-reload

# Final message
echo "Disk $device has been completely stripped down."

# read example with y/n
# read -p "Do you want to remove all references to $device from /etc/fstab? (y/n): " answer
# if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then

