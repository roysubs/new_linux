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

convert_size() {
    size="$1"

    # Normalize input to uppercase for standard interpretation
    size=$(echo "$size" | tr 'a-z' 'A-Z')

    # Add 'B' to sizes without a suffix for consistency (assume bytes)
    if [[ "$size" =~ ^[0-9]+$ ]]; then
        size="${size}B"
    fi

    # Validate the size format (e.g., 50MB, 1G, 1024K)
    if [[ ! "$size" =~ ^[0-9]+(B|[KMGTP](B)?)$ ]]; then
        echo "Error: Invalid partition size format."
        exit 1
    fi

    # Extract numeric value and suffix
    number=$(echo "$size" | grep -oP '^[0-9]+')
    unit=$(echo "$size" | grep -oP '[KMGTP]?B?$' | tr -d 'B')

    # Define multipliers for binary interpretation
    declare -A multipliers=(["K"]=1024 ["M"]=$((1024**2)) ["G"]=$((1024**3)) ["T"]=$((1024**4)) ["P"]=$((1024**5)))

    # Handle no suffix (assume bytes)
    if [ -z "$unit" ]; then
        echo "$number"
        return
    fi

    # Calculate the size in bytes
    size_in_bytes=$((number * multipliers[$unit]))

    echo "$size_in_bytes"
}

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo "$0" "$@"
fi

# Display the current lsblk, including UUID
run_command lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,UUID,MOUNTPOINTS
echo "# RM (Removable drive), RO (Read-only)"

# Check if device argument is provided
if [ -z "$1" ]; then
    echo
    echo -e "Usage: $0 /dev/sdX [Size]"
    echo "Size can be in any unit (e.g., 5G, 100M). Default: all free space."
    echo
    exit 1
fi

device=$1
partition_size=$2  # Optional size
sector_size=$(blockdev --getss "$device")

# Step 1: Check if the disk has a valid partition table
echo "Step 1: Check if the disk has a valid partition table"
partition_table=$(parted "$device" print 2>&1)
if echo "$partition_table" | grep -q "unrecognised disk label"; then
    echo "No valid partition table found on $device. Creating a new partition table..."
    run_command parted --script "$device" mklabel gpt
fi

# Step 2: Check current partition usage and calculate free space
echo "Step 2: Checking current partition usage and available space on $device"

# Find the end sector of sdb1
last_partition_end=$(lsblk -o NAME,START,SIZE "$device" | grep -e "sdb1" | awk '{print $2 + $3}')

# If partition size is provided, convert it to sectors
if [ -z "$partition_size" ]; then
    # If no size, use available space after sdb1
    start_sector=$((last_partition_end + 1))
else
    partition_size_in_bytes=$(convert_size "$partition_size")
    partition_size_in_sectors=$((partition_size_in_bytes / sector_size))
    start_sector=$((last_partition_end + 1))
fi

# Align start sector to a common boundary (2048 is a typical alignment)
aligned_start=$(( (start_sector + 2047) / 2048 * 2048 ))

# Check if there is enough space for the new partition
free_space=$(lsblk -o NAME,START,SIZE "$device" | grep -e "$device" | tail -n 1 | awk '{print $2 + $3}')
if [ "$aligned_start" -ge "$free_space" ]; then
    echo "Error: No sufficient space available after sdb1 for the new partition."
    exit 1
fi

# Create the partition starting at the aligned sector
aligned_end=$((aligned_start + partition_size_in_sectors))

echo "Creating a partition starting at sector $aligned_start and ending at $aligned_end..."
run_command parted --script "$device" mkpart primary ext4 ${aligned_start}s ${aligned_end}s

# Step 3: Format the partition
echo "Step 3: Formatting the new partition as ext4"
new_partition=$(lsblk -lnf | tail -n 1 | awk '{print $1}')
echo "New partition detected: $new_partition"

echo "Formatting $new_partition as ext4..."
run_command mkfs.ext4 "$new_partition"

# Step 4: Mount the partition and add to /etc/fstab
echo "Step 4: Mount the partition and add to /etc/fstab"
uuid=$(blkid -s UUID -o value "$new_partition")
mount_point="/mnt/$(basename "$new_partition")"

if [ ! -d "$mount_point" ]; then
    run_command mkdir -p "$mount_point"
fi

run_command mount UUID="$uuid" "$mount_point"
echo "UUID=$uuid $mount_point ext4 defaults,nofail 0 2" >> /etc/fstab
echo "Partition mounted at $mount_point and added to /etc/fstab."

# Summary
echo
echo "Summary:"
lsblk -o NAME,SIZE,TYPE,UUID,RM,RO,MOUNTPOINTS | grep -e NAME -e $(basename "$device") --color=never

