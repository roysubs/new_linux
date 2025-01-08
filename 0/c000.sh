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
    local size=$1
    if [[ "$size" =~ ^([0-9]+)([kKmMgGtTpP]?)?[bB]?$ ]]; then
        local value=${BASH_REMATCH[1]}
        local unit=${BASH_REMATCH[2],,} # Convert to lowercase for consistency
        case $unit in
            k) value=$((value * 1024)) ;; # Kilobytes
            m) value=$((value * 1024 * 1024)) ;; # Megabytes
            g) value=$((value * 1024 * 1024 * 1024)) ;; # Gigabytes
            t) value=$((value * 1024 * 1024 * 1024 * 1024)) ;; # Terabytes
            p) value=$((value * 1024 * 1024 * 1024 * 1024 * 1024)) ;; # Petabytes
            "") ;; # Bytes, no conversion needed
            *) echo "Invalid unit: $unit"; exit 1 ;;
        esac
        echo $value
    else
        echo "Invalid size format: $size"; exit 1
    fi
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
echo
echo "Step 1: Check if the disk has a valid partition table"
partition_table=$(parted --script "$device" print 2>&1)
if echo "$partition_table" | grep -q "unrecognised disk label"; then
    echo "No valid partition table found on $device. Creating a new partition table..."
    run_command parted --script "$device" mklabel gpt
fi

# Get disk info in sectors
echo "Gathering disk information in sectors..."
disk_info=$(parted --script "$device" unit s print free)

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

# Convert partition size to sectors (if provided)
if [ -n "$partition_size" ]; then
    human_readable_size="$partition_size"
    partition_size_bytes=$(convert_size "${partition_size}")
    
    # Check if the conversion was successful
    if [ $? -ne 0 ]; then
        echo "Error: Invalid partition size format."
        exit 1
    fi
    
    partition_size_sectors=$((partition_size_bytes / sector_size))

    if [ "$partition_size_sectors" -gt "$largest_size" ]; then
        echo "Error: Requested size ($human_readable_size) exceeds available space."
        exit 1
    fi

    # Calculate end sector for the new partition
    aligned_end=$((aligned_start + partition_size_sectors - 1))
    if [ "$aligned_end" -gt "$largest_end" ]; then
        aligned_end="$largest_end"
    fi

    echo "Creating partition of size $human_readable_size ($partition_size_bytes bytes)"
else
    aligned_end="$largest_end"
fi

run_command parted --script "$device" mkpart primary ext4 ${aligned_start}s ${aligned_end}s

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
