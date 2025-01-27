#!/bin/bash

# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Elevation required; rerunning as sudo..."
    exec sudo "$0" "$@"
fi

# Function to run a command and handle errors
run_command() {
    echo "Running: $@"
    "$@"
    if [ $? -ne 0 ]; then
        echo "Command failed: $@"
        exit 1
    fi
}

# Function to check if the disk has a valid partition table
check_partition_table() {
    echo "Step 1: Check if the disk has a valid partition table"
    lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,UUID,MOUNTPOINTS

    # Check for the presence of a partition table on the disk
    if ! lsblk "$1" | grep -q "part"; then
        echo "No valid partition table found on $1. Creating a new partition table..."
        run_command parted --script "$1" mklabel gpt
    fi
}

# Function to create a new partition on the disk
create_partition() {
    local device=$1
    local size=$2

    echo "Step 2: Creating a new partition on $device"
    local size_bytes=$(echo "$size" | awk '{print $1 * 1024 * 1024}')
    echo "Creating partition of size $size ($size_bytes bytes)"
    
    run_command parted --script "$device" mkpart primary ext4 2048s "$size_bytes"s
    run_command partprobe "$device"
    sleep 2  # Allow time for partition table to refresh
}

# Function to format the new partition
format_partition() {
    echo "Step 3: Formatting the new partition"

    # Get the new partition
    new_partition=$(lsblk -lnp -o NAME "$1" | grep -E "^$1[0-9]+$" | tail -n 1)

    # Ensure the partition exists
    if [ -z "$new_partition" ]; then
        echo "Error: No new partition detected."
        exit 1
    fi

    echo "Found new partition: $new_partition"
    run_command mkfs.ext4 "$new_partition"

    # Check if formatting succeeded
    if [ $? -eq 0 ]; then
        echo "Partition $new_partition successfully formatted as ext4."
    else
        echo "Error: Failed to format $new_partition as ext4."
        exit 1
    fi
}

# Main script logic
if [ $# -ne 2 ]; then
    echo "Usage: $0 <device> <size>"
    echo "Example: $0 /dev/sdb 50mb"
    exit 1
fi

device=$1
size=$2

# Step 1: Check if the disk has a valid partition table
check_partition_table "$device"

# Step 2: Create a new partition
create_partition "$device" "$size"

# Step 3: Format the new partition
format_partition "$device"

