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
            k) value=$((value * 1024)) ;; # Kilobytes (KiB)
            m) value=$((value * 1024 * 1024)) ;; # Megabytes (MiB)
            g) value=$((value * 1024 * 1024 * 1024)) ;; # Gigabytes (GiB)
            t) value=$((value * 1024 * 1024 * 1024 * 1024)) ;; # Terabytes (TiB)
            p) value=$((value * 1024 * 1024 * 1024 * 1024 * 1024)) ;; # Petabytes (PiB)
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

if [ -z "$1" ]; then
    echo
    echo -e "Usage:  $(basename "$0") /dev/sdX [Size]"
    echo "sdX: The disk to operate on; this will usually be one of sda, sdb, sdc, ..."
    echo "Size: The size of partition to create. Accepts any unit, in upper or lower case."
    echo "e.g. 5G or 5gb, 1PB, 100m or 100MB, 500kb, etc"
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

# Create partition using parted
run_command parted --script "$device" mkpart primary ext4 ${aligned_start}s ${aligned_end}s

# Refresh the partition table and ensure the new partition is recognized
run_command partprobe "$device"  # Forces kernel to reload the partition table
sleep 2

# Step 3: Formatting the new partition
echo
echo "Step 3: Formatting the new partition"
new_partition=$(lsblk -lnp -o NAME "$device" | grep -E "^$device[0-9]+$" | tail -n 1)

# Ensure the partition exists
if [ -z "$new_partition" ]; then
    echo "Error: No new partition detected."
    exit 1
fi

# Format the partition
# lazy_itable_init / lazy_journal_init will run those after the initial format
# mkfs.ext4 -F -E lazy_itable_init=1,lazy_journal_init=1 -m 0 -O ^has_journal /dev/sdb1
# -F              : Force formatting even if a filesystem exists.
# -E lazy_*       : Initialize inode and journal tables lazily (after the initial format completes).
# -m 0            : Reduce reserved space to 0%.
# -O ^has_journal : Skip journaling.
run_command mkfs.ext4 -E lazy_itable_init=1,lazy_journal_init=1 "$new_partition"
# Check if formatting succeeded
if [ $? -eq 0 ]; then
    echo "Partition $new_partition successfully formatted as ext4."
else
    echo "Error: Failed to format $new_partition as ext4."
    exit 1
fi

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

    # Check if the share already exists
    if grep -q "^\[$share_name\]" "$smb_conf"; then
        echo "Samba share $share_name already exists. It will not be updated."
    else
        # Add new Samba share
        echo -e "\n" >> "$smb_conf"
        echo -e "[$share_name]" >> "$smb_conf"
        echo -e "  path = $mount_point" >> "$smb_conf"
        echo -e "  read only = no" >> "$smb_conf"
        echo -e "  browsable = yes" >> "$smb_conf"
        echo -e "  guest ok = yes" >> "$smb_conf"
        echo -e "  create mask = 0755" >> "$smb_conf"
        echo -e "  directory mask = 0775" >> "$smb_conf"
        echo -e "  comment = Added by script" >> "$smb_conf"

        # Restart Samba services
        run_command systemctl restart smbd
        run_Command systemctl restart nmbd

        echo "Samba share $share_name created."
    fi
else
    echo "Samba tools not installed. Skipping Samba share creation."
fi

# path = /mnt/sdb1
# valid users = boss
# read only = no
# browsable = yes
# guest ok = no
# create mask = 0775
# directory mask = 0775
# comment = Added by script
#     echo -e "
#   [$share_name]
#   path = $mount_point
#   read only = no
#   browsable = yes
#   guest ok = yes
#   create mask = 0755
#   directory mask = 0775
#   comment = Added by script
# " >> "$smb_conf"
#
# Additional Samba Settings and Explanations:
# valid users: Specifies users allowed to access the share. E.g., valid users = boss john.
# write list: Specifies users allowed to write to the share, overriding read only. E.g., write list = john.
# force user: Forces all file operations to use a specific user account. E.g., force user = sambauser.
# force group: Similar to force user but applies to the group. E.g., force group = sambagroup.
# vfs objects: Enables additional Samba features like recycle bins. E.g., vfs objects = recycle.
# hide files: Hides files matching a pattern. E.g., hide files = /desktop.ini/Thumbs.db/.
# inherit permissions: Ensures new files inherit the parent directory's permissions. E.g., inherit permissions = yes.
# max connections: Limits the number of simultaneous connections. E.g., max connections = 5.
# hosts allow: Restricts access to specific IPs. E.g., hosts allow = 192.168.1.0/24.
# log file: Specifies the Samba log file location. E.g., log file = /var/log/samba/log.%m.
#
# smbd vs nmbd
# smbd: Handles file sharing, printing, and authentication for SMB/CIFS clients.
# nmbd: Manages NetBIOS name resolution and browsing. Required if your network relies on NetBIOS.
# For most modern setups, restarting both smbd and nmbd is necessary to ensure complete functionality. If your network uses DNS instead of NetBIOS, nmbd may not be required.



echo "Summary:"
echo
echo -e "\033[34mlsblk | grep -e NAME -e sdb --color=never\033[0m"
lsblk | grep -e NAME -e sdb --color=never
echo
echo -e "\033[34mdf -h | grep -e Filesystem -e /dev/sdb --color=never\033[0m"
df -h | grep -e Filesystem -e /dev/sdb --color=never
echo
echo "All steps completed successfully for $device."

# Note filesystem overheads when formatting.
# e.g. formatting a small 50mb partition with ext4 shows 42mb usable space.
# This is because space is used for:
# - Superblock: Contains metadata about the filesystem (size, block count, etc.).
# - Inodes: Structures used to store file metadata.
# - Journaling: If the filesystem supports journaling (e.g., ext4), additional space is reserved.
# - Reserved Blocks: By default, 5% of the filesystem is often reserved for system processes (configurable with tune2fs).
# 
#                                                   Size        Avail
# For a   5gb ext4 formatted partition:  /dev/sdb1  4.9G   24K  4.6G   1% /mnt/sdb1
# For a 500mb ext4 formatted partition:  /dev/sdb1  452M   24K  417M   1% /mnt/sdb1
# For a  50mb ext4 formatted partition:  /dev/sdb1   43M   24K   40M   1% /mnt/sdb1
# For a   5mb ext4 formatted partition:  /dev/sdb1  4.7M   24K  4.4M   1% /mnt/sdb1
#    For 5mb, get warning: "Filesystem too small for a journal, Creating filesystem with 1280 4k blocks and 1280 inodes"
