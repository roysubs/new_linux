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
    echo "This script must be run as root. Exiting."
    exit 1
fi

# Check if device argument is provided
if [ -z "$1" ]; then
    echo -e "Usage: $0 /dev/sdX [size_in_GB]"
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
# Get all the Free Space lines and calculate the largest free space
echo -e "\033[34mRunning: parted --script $device unit s print free\033[0m"
parted --script "$device" unit s print free
if [ $? -ne 0 ]; then
    echo -e "\033[31mCommand failed: $*\033[0m"
    exit 1
fi
free_spaces=$(parted --script "$device" unit s print free | awk '/Free Space/ {print $1, $2, $3}')
if [ -z "$free_spaces" ]; then
    echo "No free space found on $device. Exiting."
    exit 1
fi
# Initialize variables to track the largest free space
largest_start=0
largest_end=0
largest_size=0
# Loop through each Free Space and calculate the size
while read -r start end size; do
    # Remove "s" from start-end-size values to use for calculations
    start_no_s="${start//s/}"
    end_no_s="${end//s/}"
    size_no_s="${size//s/}"
    
    # Compare to find the largest free space
    if [ "$size_no_s" -gt "$largest_size" ]; then
        largest_size="$size_no_s"
        largest_start="$start_no_s"
        largest_end="$end_no_s"
    fi
done <<< "$free_spaces"

# Display the largest free space found
echo "Largest free space detected from sector $largest_start to sector $largest_end with size $largest_size sectors."

# Capture the sector size
sector_size=$(parted --script "$device" unit s print | grep "Sector size" | awk '{print $3}')

# Align the start sector to the nearest 2048-sector boundary
aligned_start=$(( (largest_start + 2047) / 2048 * 2048 ))

# Ensure the aligned start is within the available free space
if [ "$aligned_start" -gt "$largest_end" ]; then
    echo "Error: Aligned start sector ($aligned_start) exceeds the available free space end sector ($largest_end)."
    exit 1
fi

# If a partition size is specified, calculate the end sector for it
if [ -n "$partition_size" ]; then
    # Convert partition size in GB to sectors
    partition_size_sectors=$(echo "$partition_size * 1024 * 1024 * 1024 / $sector_size" | bc)
    new_end_sector=$((aligned_start + partition_size_sectors))

    # Ensure the new end sector does not exceed the largest free space
    if [ "$new_end_sector" -gt "$largest_end" ]; then
        new_end_sector="$largest_end"
    fi

    echo "Creating a partition of $partition_size GB starting at sector $aligned_start and ending at sector $new_end_sector..."
    run_command parted --script "$device" mkpart primary ext4 ${aligned_start}s ${new_end_sector}s
else
    # If no partition size is specified, use the entire free space
    echo "Creating a partition using the largest free space from sector $aligned_start to sector $largest_end..."
    run_command parted --script "$device" mkpart primary ext4 ${aligned_start}s ${largest_end}s
fi

# Calculate and display the partition size in human-readable format
partition_size_human=$(echo "$largest_size * $sector_size / (1024 * 1024 * 1024)" | bc)
echo $partition_size_human

# Check if partition size was calculated correctly
if [ -z "$partition_size_human" ]; then
    echo "Error: Partition size could not be calculated."
else
    echo "Partition created with size: $partition_size_human GB"
fi

# Step 3: Format the partition
echo "Step 3: Formatting $new_partition as ext4"
run_command mkfs.ext4 "$new_partition"

# Step 4: Create a mount point and add to /etc/fstab
echo "Step 4: Creating mount point and updating /etc/fstab"
mount_point="/mnt/${partition_name}"
if [ ! -d "$mount_point" ]; then
    run_command mkdir -p "$mount_point"
fi
run_command mount "$new_partition" "$mount_point"
echo "$new_partition $mount_point ext4 defaults 0 2" >> /etc/fstab
echo "Mount point created and added to /etc/fstab: $mount_point"

# Step 5: Create NFS share (if installed)
if command -v exportfs &>/dev/null; then
    echo "Step 5: Creating NFS share for $mount_point"
    echo "$mount_point *(rw,sync,no_subtree_check)" >> /etc/exports
    run_command exportfs -a
    echo "NFS share created and exported."
else
    echo "Step 5: NFS share creation"
    echo "NFS tools are not installed. Skipping NFS share creation."
fi

# Step 6: Create Samba share (if installed)
if command -v smbclient &>/dev/null; then
    echo "Step 6: Creating Samba share for $mount_point"
    share_name="share_${partition_name}"
    echo -e "[$share_name]\n  path = $mount_point\n  read only = no\n  browsable = yes\n" >> /etc/samba/smb.conf
    run_command systemctl restart smbd
    echo "Samba share created and service restarted."
else
    echo "Step 6: Samba share creation"
    echo "Samba tools are not installed. Skipping Samba share creation."
fi

echo "All steps completed successfully for $device."

