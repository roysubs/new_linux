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
    
    # Replace lowercase suffixes with uppercase for standard interpretation
    size=$(echo "$size" | sed 's/[a-z]$/\U&/')

    # Validate the size format
    if [[ ! "$size" =~ ^[0-9]+(B|[KMGTP]?)$ ]]; then
        echo "Invalid size format: $size"
        return 1
    fi

    # Convert to bytes
    size_in_bytes=$(numfmt --from=iec "$size" 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo "Invalid size format: $size"
        return 1
    fi

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
    echo "Size can be in any unit with or without 'B', e.g. 5G, 1PB, 100m, 500kb, etc"
    echo
    exit 1
fi

device=$1
partition_size=$2  # Optional size in GB
sector_size=$(blockdev --getss "$device")

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
echo "Note! If the drive has not been scrubbed securely, and the start sector"
echo "coincides with a previous partition, then there may be a warning about"
echo "that. If you are sure there is no data on there, it is safe to continue."
run_command mkfs.ext4 "$new_partition"

# Step 3: Formatting the new partition as ext4
echo
echo "Step 3: Formatting the new partition"
echo "Get the newly created partition"   # e.g., /dev/sdb2
run_command lsblk -lnp -o NAME "$device" | grep -E "^$device[0-9]+$" | tail -n 1
new_partition=$(lsblk -lnp -o NAME "$device" | grep -E "^$device[0-9]+$" | tail -n 1)
run_command mkfs.ext4 "$new_partition"
# Check if formatting succeeded
if [ $? -eq 0 ]; then
    echo "Partition $new_partition successfully formatted as ext4."
else
    echo "Error: Failed to format $new_partition as ext4."
    exit 1
fi

# Step 4: Get the UUID of the newly created partition
echo
echo "Step 4: Get the UUID of the newly created partition"
echo -e "\033[34mblkid -s UUID -o value $new_partition\033[0m"
uuid=$(blkid -s UUID -o value "$new_partition")

# Step 5: Create a mount point and add to /etc/fstab using UUID
echo
echo "Step 5: Create a mount point and add to /etc/fstab using UUID"
mount_point="/mnt/$(basename "$new_partition")"
if [ ! -d "$mount_point" ]; then
    run_command mkdir -p "$mount_point"
fi
run_command mount UUID="$uuid" "$mount_point"
run_command systemctl daemon-reload
echo "UUID=$uuid $mount_point ext4 defaults,nofail 0 2" >> /etc/fstab
echo "Partition mounted at $mount_point and added with nofail to /etc/fstab."

# Step 6: Create NFS share
echo
echo "Step 6: Create NFS share (if NFS is enabled)"
if command -v exportfs &>/dev/null; then
    echo "$mount_point *(rw,sync,no_subtree_check)" >> /etc/exports
    run_command exportfs -a
    echo "NFS share created."
else
    echo "NFS tools not installed. Skipping NFS share creation."
fi

# Step 7: Create Samba share
echo
echo "Step 7: Create Samba share (if Samba is enabled)"
if command -v smbclient &>/dev/null; then
    smb_conf="/etc/samba/smb.conf"
    share_name="share_$(basename "$new_partition")"
    echo -e "[$share_name]\n  path = $mount_point\n  read only = no\n  browsable = yes\n" >> "$smb_conf"
    run_command systemctl restart smbd
    echo "Samba share $share_name created."
else
    echo "Samba tools not installed. Skipping Samba share creation."
fi

echo
echo "Summary"
echo "======="
device_name=$(basename "$device" | sed 's/^//')  # Extracts 'sdb' from '/dev/sdb'

echo
echo -e "\033[34mlsblk -o NAME,SIZE,TYPE,UUID,RM,RO,MOUNTPOINTS | grep -e NAME -e $device_name --color=never\033[0m"
lsblk -o NAME,SIZE,TYPE,UUID,RM,RO,MOUNTPOINTS | grep -e NAME -e $device_name --color=never

echo
echo -e "\033[34mgrep -e UUID -e $device_name /etc/fstab\033[0m"
grep -e UUID -e $device_name /etc/fstab

echo
echo -e "\033[34mdf -h | grep -e Filesystem -e $device --color=never\033[0m"
df -h | grep -e Filesystem -e $device --color=never

echo
echo "All steps completed successfully for $device."
