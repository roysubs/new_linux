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
    echo -e "Usage: $0 /dev/sdX [size_in_GB]"
    echo
    echo "# RM (Removable drive), RO (Read-only)"
    lsblk
    exit 1
fi

device=$1
partition_size=$2  # Optional size in GB

# Step 0: Display the current disk layout using lsblk
echo "Step 0: Displaying current disk layout using lsblk"
run_command lsblk

# Step 1: Check if the disk has a valid partition table
echo "Step 1: Check if the disk has a valid partition table"
partition_table=$(parted "$device" print 2>&1)
if echo "$partition_table" | grep -q "unrecognised disk label"; then
    echo "No valid partition table found on $device. Creating a new partition table..."
    run_command parted --script "$device" mklabel gpt
fi

# Step 2: Creating a new partition on the device
echo "Step 2: Creating a new partition on $device"
echo -e "\033[34mRunning: parted --script $device unit s print free\033[0m"
free_spaces=$(parted --script "$device" unit s print free | awk '/Free Space/ {print $1, $2, $3}')

# Initialize variables to track the largest free space
largest_start=0
largest_end=0
largest_size=0

while read -r start end size; do
    start_no_s="${start//s/}"
    end_no_s="${end//s/}"
    size_no_s="${size//s/}"
    if [ "$size_no_s" -gt "$largest_size" ]; then
        largest_size="$size_no_s"
        largest_start="$start_no_s"
        largest_end="$end_no_s"
    fi
done <<< "$free_spaces"

aligned_start=$(( (largest_start + 2047) / 2048 * 2048 ))
if [ "$aligned_start" -gt "$largest_end" ]; then
    echo "Error: Aligned start sector exceeds the available free space."
    exit 1
fi

new_partition="${device}1"

echo "Creating a partition using the largest free space from sector $aligned_start to sector $largest_end..."
run_command parted --script "$device" mkpart primary ext4 ${aligned_start}s ${largest_end}s

# Reload the partition table to ensure the system recognizes the new partition
echo "Reloading the partition table..."
run_command partprobe "$device"

# Check if the new partition exists
if [ ! -b "$new_partition" ]; then
    echo "Error: The partition $new_partition was not detected after creation."
    exit 1
fi

echo "Partition created: $new_partition with size $((largest_size * sector_size / (1024 * 1024 * 1024))) GB."

# Step 3: Format the partition
echo "Step 3: Formatting $new_partition as ext4"
run_command mkfs.ext4 "$new_partition"

# Step 4: Create a mount point and add to /etc/fstab
mount_point="/mnt/$(basename "$new_partition")"
if [ ! -d "$mount_point" ]; then
    run_command mkdir -p "$mount_point"
fi
run_command mount "$new_partition" "$mount_point"
run_command systemctl daemon-reload
echo "$new_partition $mount_point ext4 defaults 0 2" >> /etc/fstab
echo "Partition mounted at $mount_point and added to /etc/fstab."

# Step 5: Create NFS share
if command -v exportfs &>/dev/null; then
    echo "$mount_point *(rw,sync,no_subtree_check)" >> /etc/exports
    run_command exportfs -a
    echo "NFS share created."
else
    echo "NFS tools not installed. Skipping NFS share creation."
fi

# Step 6: Create Samba share
if command -v smbclient &>/dev/null; then
    smb_conf="/etc/samba/smb.conf"
    share_name="share_$(basename "$new_partition")"
    echo -e "[$share_name]\n  path = $mount_point\n  read only = no\n  browsable = yes\n" >> "$smb_conf"
    run_command systemctl restart smbd
    echo "Samba share $share_name created."
else
    echo "Samba tools not installed. Skipping Samba share creation."
fi

echo "Summary:"
echo
echo -e "\033[34mlsblk | grep -e NAME -e sdb --color=never\033[0m"
lsblk | grep -e NAME -e sdb --color=never
echo
echo -e "\033[34mdf -h | grep -e Filesystem -e /dev/sdb --color=never\033[0m"
df -h | grep -e Filesystem -e /dev/sdb --color=never
echo
echo "All steps completed successfully for $device."

