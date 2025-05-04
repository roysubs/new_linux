#!/bin/bash

# ========== PARTITION + FORMAT + MOUNT + NFS + SAMBA AUTOMATION ==========
# This script creates a new ext4 partition on a specified block device,
# formats it, mounts it, adds it to /etc/fstab, and shares it via NFS and Samba.
#
# Features:
# - Detects unpartitioned space and aligns new partition to 2048-sector boundaries.
# - Accepts optional partition size like 5G, 500M, etc.
# - Automatically formats with ext4 and creates mount point.
# - Appends to /etc/fstab (safely), exports via NFS and/or Samba if tools are available.
#
# USAGE:
#   sudo ./this_script.sh /dev/sdX [SIZE]
#
# ARGUMENTS:
#   /dev/sdX     Target block device (e.g., /dev/sdb).
#   SIZE         (Optional) Size for new partition, e.g. 5G, 100M, 500kb.
#                If omitted, uses the largest free block on disk.
#
# EXAMPLE:
#   ./script.sh /dev/sdb 5G
#
# SAFETY:
#   - Checks for root privileges.
#   - Detects and skips existing partition tables.
#   - Does not overwrite existing Samba/NFS shares.
#
# FILESYSTEM OVERHEADS WHEN FORMATTING.
# As an example, formatting a small 50mb partition with ext4 shows 42mb usable space. Space is used for:
# - Superblock: Contains metadata about the filesystem (size, block count, etc.).
# - Inodes: Structures used to store file metadata.
# - Journaling: If the filesystem supports journaling (e.g., ext4), additional space is reserved.
# - Reserved Blocks: By default, 5% of the filesystem is often reserved for system processes (configurable with tune2fs).
#                                                   Size        Avail
# For a   5gb ext4 formatted partition:  /dev/sdb1  4.9G   24K  4.6G   1% /mnt/sdb1
# For a 500mb ext4 formatted partition:  /dev/sdb1  452M   24K  417M   1% /mnt/sdb1
# For a  50mb ext4 formatted partition:  /dev/sdb1   43M   24K   40M   1% /mnt/sdb1
# For a   5mb ext4 formatted partition:  /dev/sdb1  4.7M   24K  4.4M   1% /mnt/sdb1
#    For 5mb, get warning: "Filesystem too small for a journal, Creating filesystem with 1280 4k blocks and 1280 inodes"
# ==========================================================================

# ---- Function Definitions ----

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
        local unit=${BASH_REMATCH[2],,}
        case $unit in
            k) value=$((value * 1024)) ;;
            m) value=$((value * 1024 * 1024)) ;;
            g) value=$((value * 1024 * 1024 * 1024)) ;;
            t) value=$((value * 1024 * 1024 * 1024 * 1024)) ;;
            p) value=$((value * 1024 * 1024 * 1024 * 1024 * 1024)) ;;
            "") ;;  # Bytes
            *) echo "Invalid unit: $unit"; exit 1 ;;
        esac
        echo $value
    else
        echo "Invalid size format: $size"; exit 1
    fi
}

# ---- Privilege Check ----

if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo "$0" "$@"
fi

# ---- Display Device Info ----

run_command lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,UUID,MOUNTPOINTS
echo "# RM (Removable drive), RO (Read-only)"

# ---- Parse Arguments ----

if [ -z "$1" ]; then
    echo
    echo -e "Usage: $0 /dev/sdX [Size]"
    echo "See top of script for full documentation."
    echo
    exit 1
fi

device=$1
partition_size=$2
sector_size=$(blockdev --getss "$device")

# ---- Check/Initialize Partition Table ----

echo -e "\nStep 1: Checking partition table..."
if parted --script "$device" print 2>&1 | grep -q "unrecognised disk label"; then
    echo "No valid partition table found. Creating GPT label..."
    run_command parted --script "$device" mklabel gpt
fi

# ---- Find Largest Free Block ----

echo "Step 2: Searching for free space..."
free_spaces=$(parted --script "$device" unit s print free | awk '/Free Space/ {print $1, $2, $3}')

largest_start=0
largest_end=0
largest_size=0
while read -r start end size; do
    s=${start//s/}; e=${end//s/}; z=${size//s/}
    if [ "$z" -gt "$largest_size" ]; then
        largest_size=$z; largest_start=$s; largest_end=$e
    fi
done <<< "$free_spaces"

aligned_start=$(( (largest_start + 2047) / 2048 * 2048 ))
if [ "$aligned_start" -gt "$largest_end" ]; then
    echo "Error: Aligned start sector exceeds free space."
    exit 1
fi

# ---- Optional Size Conversion ----

if [ -n "$partition_size" ]; then
    partition_size_bytes=$(convert_size "$partition_size")
    partition_size_sectors=$((partition_size_bytes / sector_size))
    if [ "$partition_size_sectors" -gt "$largest_size" ]; then
        echo "Error: Size $partition_size exceeds available free space."
        exit 1
    fi
    aligned_end=$((aligned_start + partition_size_sectors - 1))
    [ "$aligned_end" -gt "$largest_end" ] && aligned_end=$largest_end
    echo "Creating partition of size $partition_size ($partition_size_bytes bytes)"
else
    aligned_end=$largest_end
fi

# ---- Partition Creation ----

run_command parted --script "$device" mkpart primary ext4 ${aligned_start}s ${aligned_end}s
run_command partprobe "$device"
sleep 2

# ---- Format New Partition ----

new_partition=$(lsblk -lnp -o NAME "$device" | grep -E "^$device[0-9]+$" | tail -n 1)
[ -z "$new_partition" ] && { echo "Error: No partition detected."; exit 1; }

run_command mkfs.ext4 -E lazy_itable_init=1,lazy_journal_init=1 "$new_partition"
echo "Partition $new_partition formatted as ext4."

# ---- Mount Setup ----

mount_point="/mnt/$(basename "$new_partition")"
[ ! -d "$mount_point" ] && run_command mkdir -p "$mount_point"
run_command mount "$new_partition" "$mount_point"

if ! grep -q "$new_partition" /etc/fstab; then
    echo "$new_partition $mount_point ext4 defaults 0 2" >> /etc/fstab
fi

run_command systemctl daemon-reexec
echo "Mounted at $mount_point and added to /etc/fstab."

# ---- Optional NFS Share ----

if command -v exportfs &>/dev/null; then
    if ! grep -q "$mount_point" /etc/exports; then
        echo "$mount_point *(rw,sync,no_subtree_check)" >> /etc/exports
        run_command exportfs -a
        echo "NFS share created for $mount_point."
    else
        echo "NFS share already exists for $mount_point."
    fi
else
    echo "NFS tools not found. Skipping NFS share."
fi

# ---- Optional Samba Share ----

if command -v smbclient &>/dev/null; then
    smb_conf="/etc/samba/smb.conf"
    share_name="share_$(basename "$new_partition")"

    if grep -q "^\[$share_name\]" "$smb_conf" || grep -q "path = $mount_point" "$smb_conf"; then
        echo "Samba share already exists for $mount_point."
    else
        {
            echo -e "\n[$share_name]"
            echo "  path = $mount_point"
            echo "  read only = no"
            echo "  browsable = yes"
            echo "  guest ok = yes"
            echo "  create mask = 0755"
            echo "  directory mask = 0775"
            echo "  comment = Added by script"
        } >> "$smb_conf"
        run_command systemctl restart smbd
        run_command systemctl restart nmbd
        echo "Samba share $share_name created."
    fi
else
    echo "Samba tools not found. Skipping Samba share."
fi

# ---- Summary ----

echo -e "\n\033[34mPartitioning Summary\033[0m"
dev_base=$(basename "$device")
part_base=$(basename "$new_partition")

echo -e "\n\033[34mlsblk:\033[0m"
lsblk | grep -e NAME -e "$dev_base" --color=never

echo -e "\n\033[34mdf -h:\033[0m"
df -h | grep -e Filesystem -e "/dev/$part_base" --color=never

echo -e "\n\033[32mAll steps completed successfully for $device.\033[0m"

