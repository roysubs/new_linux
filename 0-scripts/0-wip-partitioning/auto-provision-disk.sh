#!/bin/bash

# Author: Roy Wiseman, 2025-04

# ========== ADVANCED PARTITION + FORMAT + MOUNT + SHARE AUTOMATION ==========
#
# This script automates creating a new ext4 partition, formatting it,
# mounting it, adding it to /etc/fstab, and optionally sharing it via NFS and Samba.
#
# Features:
# - Root privilege check with auto-sudo elevation.
# - Creates a GPT partition table if one doesn't exist.
# - Uses the largest available free space or a user-specified size.
# - Supports human-readable sizes for partitions (e.g., 5G, 100M, 2T).
# - Aligns new partition to 1MiB boundaries.
# - Formats the new partition as ext4 with lazy init options.
# - Mounts the partition using its UUID for robustness.
# - Adds the partition to /etc/fstab with the 'nofail' option.
# - Idempotent checks for /etc/fstab, /etc/exports, and smb.conf entries.
# - Optionally creates NFS and Samba shares if the respective tools are installed.
# - Provides clear output and error handling.
#
# USAGE:
#   sudo ./this_script_name.sh /dev/sdX [SIZE]
#
# ARGUMENTS:
#   /dev/sdX      Target block device (e.g., /dev/sdb, /dev/nvme0n1). MANDATORY.
#   SIZE          (Optional) Desired size for the new partition.
#                 Examples: 5G, 100M, 2T, 500K.
#                 If omitted, the script uses the largest available contiguous free space.
#
# EXAMPLES:
#   sudo ./this_script_name.sh /dev/sdb 100G
#   sudo ./this_script_name.sh /dev/sdc
#
# SAFETY:
# - Always double-check the target device (/dev/sdX) before running!
# - The script operates on disk partitions and requires root privileges.
#   Incorrect use can lead to data loss.
# - It checks for existing mounts before formatting.
# - It tries not to duplicate existing configurations in fstab, exports, or smb.conf.
#
# ==========================================================================

# ---- Helper Functions ----

run_command() {
    echo -e "\033[34mRunning: $*\033[0m"
    eval "$*" # Using eval can be risky if input is not controlled. Consider alternatives if commands are complex and user-influenced.
    if [ $? -ne 0 ]; then
        echo -e "\033[31mERROR: Command failed (exit code $?): $*\033[0m"
        exit 1
    fi
}

convert_size() {
    local size_in="$1"
    local size_val
    local size_unit
    local value_bytes

    # Normalize input to uppercase for unit matching
    local size_upper=$(echo "$size_in" | tr 'a-z' 'A-Z')

    if [[ ! "$size_upper" =~ ^([0-9]+(\.[0-9]+)?)([KMGTP]?B?)?$ ]]; then
        echo -e "\033[31mERROR: Invalid size format '$size_in'. Use format like 5G, 100MB, 2T.\033[0m"
        return 1
    fi

    size_val=$(echo "$size_upper" | grep -oP '^[0-9]+(\.[0-9]+)?')
    size_unit=$(echo "$size_upper" | grep -oP '[KMGTP]?B?$' | sed 's/B$//')

    # Using awk for floating point multiplication for precision with decimal inputs
    case $size_unit in
        K) value_bytes=$(awk -v val="$size_val" 'BEGIN { print val * 1024 }') ;;
        M) value_bytes=$(awk -v val="$size_val" 'BEGIN { print val * 1024 * 1024 }') ;;
        G) value_bytes=$(awk -v val="$size_val" 'BEGIN { print val * 1024 * 1024 * 1024 }') ;;
        T) value_bytes=$(awk -v val="$size_val" 'BEGIN { print val * 1024 * 1024 * 1024 * 1024 }') ;;
        P) value_bytes=$(awk -v val="$size_val" 'BEGIN { print val * 1024 * 1024 * 1024 * 1024 * 1024 }') ;;
        ""|B) value_bytes="$size_val" ;;
        *)
            echo -e "\033[31mERROR: Invalid size unit in '$size_in'. Supported units: K, M, G, T, P (or no unit for bytes).\033[0m"
            return 1
            ;;
    esac
    # Convert to integer as byte counts should be whole numbers
    printf "%.0f\n" "$value_bytes"
    return 0
}

# ---- Initial Checks and Setup ----

echo -e "\033[1;36mStarting Advanced Partitioning and Sharing Script...\033[0m"

if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[33mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo -E "$0" "$@" # -E to preserve environment might be useful
fi

if [ -z "$1" ]; then
    echo -e "\033[31mUsage: $0 /dev/sdX [Size]\033[0m"
    echo "Please specify the target device (e.g., /dev/sdb)."
    echo "For full documentation, see the header of this script."
    exit 1
fi

device="$1"
user_requested_size="$2"

if [ ! -b "$device" ]; then
    echo -e "\033[31mERROR: Device '$device' is not a valid block device.\033[0m"
    lsblk -dpno NAME,TYPE,SIZE,MODEL # -d for device, -p for full path, no headers
    exit 1
fi

echo -e "\n\033[1;33mPhase 1: Device Information and Preparation\033[0m"
echo "Target device: $device"
[ -n "$user_requested_size" ] && echo "Requested partition size: $user_requested_size"

echo "Current lsblk output for all devices:"
run_command lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,FSTYPE,UUID,MOUNTPOINTS
echo "Details for $device:"
run_command lsblk "$device" -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,FSTYPE,UUID,MOUNTPOINTS

sector_size_bytes=$(blockdev --getss "$device")
if [ $? -ne 0 ] || ! [[ "$sector_size_bytes" =~ ^[0-9]+$ ]] || [ "$sector_size_bytes" -eq 0 ]; then
    echo -e "\033[33mWARNING: Could not determine sector size for $device using blockdev. Trying parted...\033[0m"
    sector_size_bytes=$(parted --script "$device" unit B print | awk '/Sector size \(logical\/physical\):/ {gsub(/B/,"",$3); print $3; exit}')
    if ! [[ "$sector_size_bytes" =~ ^[0-9]+$ ]] || [ "$sector_size_bytes" -eq 0 ]; then
        echo -e "\033[31mERROR: Failed to determine sector size for $device. Exiting.\033[0m"
        exit 1
    fi
    echo "Determined sector size (via parted fallback): $sector_size_bytes bytes"
else
    echo "Determined sector size (via blockdev): $sector_size_bytes bytes"
fi

echo -e "\n\033[1mStep 1: Checking partition table on $device...\033[0m"
if ! parted --script "$device" print >/dev/null 2>&1; then
    echo "No valid partition table found on $device or device may be empty."
    echo "Creating a new GPT partition table..."
    run_command parted --script "$device" mklabel gpt
    echo "GPT partition table created."
elif parted --script "$device" print 2>&1 | grep -qi "unrecognised disk label"; then # Check for specific error message
    echo "Unrecognised disk label on $device."
    echo "Creating a new GPT partition table..."
    run_command parted --script "$device" mklabel gpt
    echo "GPT partition table created."
else
    echo "Existing partition table found on $device."
fi
echo "Current partition layout on $device:"
run_command parted --script "$device" print free


echo -e "\n\033[1;33mPhase 2: Partition Definition and Creation\033[0m"
echo "Analyzing free space on $device (units in sectors)..."
parted_free_output=$(parted --script "$device" unit s print free)
echo "$parted_free_output"

largest_start_s=0
largest_end_s=0
largest_size_s=0

# Parse 'parted unit s print free' output for the largest "Free Space" segment
# It usually looks like: "  Free Space  [START]s  [END]s  [SIZE]s"
while IFS= read -r line; do
    if echo "$line" | grep -q "Free Space"; then
        # Extract numbers followed by 's', trying to be robust
        current_start_s=$(echo "$line" | awk '{for(i=1;i<=NF;i++) if($i~/[0-9]+s$/ && $(i-1)=="Space"){print $i; exit}}' | sed 's/s$//')
        # Assuming end and size follow start if the line format is consistent
        # This parsing can be fragile; needs careful testing with various parted outputs.
        # A more robust awk script might be needed for complex cases.
        # For now, trying to find numbers on the line after "Free Space".
        numbers_on_line=($(echo "$line" | grep -o '[0-9]\+s'))
        if [ ${#numbers_on_line[@]} -ge 3 ]; then # Need at least 3 numbers (start, end, size)
             # Find index of 'Free Space' then take next 3 numbers
            local i
            local found_space=0
            local temp_start temp_end temp_size
            local arr=($line)
            for i in "${!arr[@]}"; do
                if [[ "${arr[$i]}" == "Space" && "${arr[$((i-1))]}" == "Free" ]]; then
                    found_space=1
                    temp_start=$(echo "${arr[$((i+1))]}" | sed 's/s$//')
                    temp_end=$(echo "${arr[$((i+2))]}" | sed 's/s$//')
                    temp_size=$(echo "${arr[$((i+3))]}" | sed 's/s$//')
                    break
                fi
            done

            if [[ "$found_space" -eq 1 && "$temp_start" =~ ^[0-9]+$ && "$temp_end" =~ ^[0-9]+$ && "$temp_size" =~ ^[0-9]+$ ]]; then
                if [ "$temp_size" -gt "$largest_size_s" ]; then
                    largest_size_s="$temp_size"
                    largest_start_s="$temp_start"
                    largest_end_s="$temp_end" # This is actually the end of the free block reported by parted
                fi
            fi
        fi
    fi
done <<< "$(echo "$parted_free_output" | grep "Free Space")"


if [ "$largest_size_s" -eq 0 ]; then
    echo -e "\033[31mERROR: No usable 'Free Space' segments found on $device by parsing parted output.\033[0m"
    echo "Please check the 'parted print free' output above. You might need to manually manage partitions."
    exit 1
fi

echo "Identified largest free block: StartSector=${largest_start_s}s, EndSector=${largest_end_s}s, SizeInSectors=${largest_size_s}s"
# Note: parted's "end" for free space is the last sector of that space. Parted "mkpart" expects start and end, inclusive.
# The size reported by parted for Free Space is the count of sectors.
# So, largest_end_s from parted is indeed the end sector of that free block.

# Alignment: 1MiB = 1048576 bytes. sectors_for_1mib = 1048576 / sector_size_bytes
sectors_for_1mib_alignment=$((1048576 / sector_size_bytes))
sectors_for_1mib_alignment=$((sectors_for_1mib_alignment > 0 ? sectors_for_1mib_alignment : 1)) # Ensure at least 1

# Align start: round UP to the nearest multiple of sectors_for_1mib_alignment
aligned_start_s=$(( ( (largest_start_s + sectors_for_1mib_alignment - 1) / sectors_for_1mib_alignment ) * sectors_for_1mib_alignment ))

# Ensure aligned_start is not before the actual free space starts or too far in
if [ "$aligned_start_s" -lt "$largest_start_s" ]; then
     aligned_start_s=$((aligned_start_s + sectors_for_1mib_alignment)) # Try next boundary if rounding down went too far
fi
# Ensure aligned_start_s is within the free block, not beyond its end
if [ "$aligned_start_s" -ge "$largest_end_s" ]; then
    echo -e "\033[31mERROR: Calculated aligned start sector ($aligned_start_s) is at or beyond the largest free block end ($largest_end_s).\033[0m"
    exit 1
fi
echo "Calculated aligned start sector for new partition: ${aligned_start_s}s"

# Determine partition end sector
actual_end_s=""
partition_size_desc=""
max_possible_sectors_from_aligned_start=$((largest_end_s - aligned_start_s)) # Max usable sectors

if [ -n "$user_requested_size" ]; then
    echo "User requested size: $user_requested_size"
    requested_bytes=$(convert_size "$user_requested_size")
    if [ $? -ne 0 ] || [ -z "$requested_bytes" ]; then
        echo -e "\033[31mERROR: Invalid size conversion for '$user_requested_size'. Exiting.\033[0m"
        exit 1
    fi
    echo "Requested size in bytes: $requested_bytes"

    if [ "$sector_size_bytes" -eq 0 ]; then
         echo -e "\033[31mERROR: Sector size is 0, cannot calculate sectors. Exiting.\033[0m"; exit 1;
    fi
    requested_sectors=$((requested_bytes / sector_size_bytes))
    echo "Requested size in sectors: $requested_sectors"

    if [ "$requested_sectors" -le 0 ]; then
        echo -e "\033[31mERROR: Requested size results in zero or negative sectors. Exiting.\033[0m"; exit 1;
    fi
    
    if [ "$requested_sectors" -gt "$max_possible_sectors_from_aligned_start" ]; then
        echo -e "\033[33mWARNING: Requested size ($requested_sectors sectors) exceeds available space ($max_possible_sectors_from_aligned_start sectors) from aligned start.\033[0m"
        echo "Using maximum available space from aligned start instead."
        actual_end_s="$largest_end_s" # Use the end of the free block
        partition_size_desc="maximum available (${max_possible_sectors_from_aligned_start} sectors)"
    else
        actual_end_s=$((aligned_start_s + requested_sectors -1)) # -1 because parted mkpart end is inclusive
        partition_size_desc="$user_requested_size (${requested_sectors} sectors)"
    fi
else
    echo "No specific size requested. Using all available space in the largest free block from aligned start."
    actual_end_s="$largest_end_s"
    partition_size_desc="maximum available (${max_possible_sectors_from_aligned_start} sectors)"
fi

if [ "$aligned_start_s" -ge "$actual_end_s" ]; then
    echo -e "\033[31mERROR: Partition start sector ($aligned_start_s) is not less than end sector ($actual_end_s).\033[0m"
    echo "Min partition size might be 1 sector. Check free space and requested size. Cannot create partition."
    exit 1
fi

echo "Final decision for partition: Start=${aligned_start_s}s, End=${actual_end_s}s (Intended size: $partition_size_desc)"
run_command parted --script -a optimal "$device" mkpart primary ext4 ${aligned_start_s}s ${actual_end_s}s

echo "Reloading partition table for $device..."
run_command partprobe "$device"
sleep 2 

echo "Identifying the new partition on $device..."
# lsblk -lnp -o NAME device | grep -E "^${device_escaped}[p]?[0-9]+$" | tail -n 1
# Need to escape $device for grep if it contains special chars like /dev/nvme0n1
device_escaped=$(echo "$device" | sed 's/\//\\\//g') # Escape slashes for grep pattern
new_partition=$(lsblk -rnp -o NAME,TYPE | awk -v dev="^${device_escaped}[p]?[0-9]+$" '$1 ~ dev && $2 == "part" {print $1}' | tail -n 1)


if [ -z "$new_partition" ]; then
    echo -e "\033[31mERROR: Failed to detect the new partition on $device after 'parted mkpart' and 'partprobe'.\033[0m"
    echo "Please check 'lsblk $device' output manually."
    lsblk "$device"
    exit 1
fi
echo "New partition detected: $new_partition"


echo -e "\n\033[1;33mPhase 3: Formatting and Mounting $new_partition\033[0m"
if mount | grep -q "^$new_partition "; then
    echo -e "\033[31mERROR: $new_partition is ALREADY MOUNTED. Unmount it or choose a different device/partition. Exiting to prevent data loss.\033[0m"
    exit 1
fi

echo "Formatting $new_partition as ext4 (with lazy init options)..."
run_command mkfs.ext4 -F -E lazy_itable_init=1,lazy_journal_init=1 "$new_partition" # -F to force if old fs detected
echo "$new_partition formatted as ext4."

mount_point_basename=$(basename "$new_partition")
mount_point="/mnt/$mount_point_basename"

if [ ! -d "$mount_point" ]; then
    echo "Creating mount point directory: $mount_point..."
    run_command mkdir -p "$mount_point"
fi

echo "Getting UUID for $new_partition..."
uuid=$(blkid -s UUID -o value "$new_partition")
if [ -z "$uuid" ]; then
    echo -e "\033[31mERROR: Could not get UUID for $new_partition. Cannot proceed with mount/fstab.\033[0m"; exit 1;
fi
echo "UUID for $new_partition is $uuid"

echo "Mounting $new_partition (UUID=$uuid) at $mount_point..."
run_command mount UUID="$uuid" "$mount_point"
echo "$new_partition successfully mounted at $mount_point."

fstab_entry="UUID=$uuid $mount_point ext4 defaults,nofail 0 2"
fstab_file="/etc/fstab"
echo "Checking $fstab_file for existing entry for UUID $uuid or mount point $mount_point..."
if grep -q "UUID=$uuid" "$fstab_file" || grep -q " $mount_point " "$fstab_file"; then
    echo -e "\033[33mWARNING: An entry for UUID $uuid or mount point $mount_point likely already exists in $fstab_file. Not adding a new one.\033[0m"
    grep --color=always -E "(UUID=$uuid| $mount_point )" "$fstab_file"
else
    echo "Adding to $fstab_file: $fstab_entry"
    # Securely append to fstab
    if echo "$fstab_entry" | sudo tee -a "$fstab_file" > /dev/null; then
        echo "Entry successfully added to $fstab_file."
    else
        echo -e "\033[31mERROR: Failed to append to $fstab_file. Manual addition may be required.\033[0m"
    fi
fi

echo "Reloading systemd manager configuration (this may take a moment)..."
run_command systemctl daemon-reexec


echo -e "\n\033[1;33mPhase 4: Optional Network Sharing Setup\033[0m"
exports_file="/etc/exports"
nfs_share_options="*(rw,sync,no_subtree_check,all_squash,anonuid=$(id -u),anongid=$(id -g))" # Example, adjust as needed

echo -e "\n\033[1mSetting up NFS Share (if NFS tools are installed)...\033[0m"
if command -v exportfs &>/dev/null; then
    echo "NFS tools (exportfs) found."
    if grep -q "^\s*${mount_point//\//\\/}[[:space:]]" "$exports_file"; then # Escape slashes in mount_point for grep
        echo -e "\033[33mWARNING: NFS share for $mount_point appears to exist in $exports_file. Not adding.\033[0m"
        grep --color=always "^\s*${mount_point//\//\\/}[[:space:]]" "$exports_file"
    else
        nfs_share_entry="$mount_point $nfs_share_options"
        echo "Adding NFS share to $exports_file: $nfs_share_entry"
        if echo "$nfs_share_entry" | sudo tee -a "$exports_file" > /dev/null; then
            echo "NFS share entry added. Exporting shares..."
            run_command exportfs -ra
            run_command exportfs -v # Show current exports
            echo "NFS share for $mount_point configured."
        else
             echo -e "\033[31mERROR: Failed to append to $exports_file for NFS share.\033[0m"
        fi
    fi
    if systemctl is-active --quiet nfs-server || systemctl is-active --quiet nfs-kernel-server; then
        echo "NFS server service is active."
    else
        echo -e "\033[33mWARNING: NFS server service (e.g., nfs-kernel-server) may not be active or installed.\033[0m"
    fi
else
    echo "NFS tools (exportfs) not found. Skipping NFS share creation."
fi

smb_conf_file="/etc/samba/smb.conf"
samba_share_name="share_$(basename "$new_partition" | sed 's/[^a-zA-Z0-9_-]//g')" # Sanitize name
samba_share_config_block="\n[$samba_share_name]\n   path = $mount_point\n   browseable = yes\n   writable = yes\n   guest ok = yes\n   read only = no\n   create mask = 0664\n   directory mask = 0775\n"

echo -e "\n\033[1mSetting up Samba Share (if Samba tools are installed)...\033[0m"
if command -v smbd &>/dev/null; then
    echo "Samba tools (smbd) found."
    # Escape mount_point for grep pattern
    escaped_mount_point_path=$(echo "$mount_point" | sed 's/[].[*^$(){}?+|/\\]/\\&/g')
    if grep -qE "(^\[$samba_share_name\]|^\s*path\s*=\s*$escaped_mount_point_path\s*$)" "$smb_conf_file"; then
        echo -e "\033[33mWARNING: A Samba share named '$samba_share_name' or for path '$mount_point' likely exists in $smb_conf_file. Not adding.\033[0m"
        grep --color=always -A6 -E "(^\[$samba_share_name\]|^\s*path\s*=\s*$escaped_mount_point_path\s*$)" "$smb_conf_file" | head -n 7
    else
        echo "Adding Samba share to $smb_conf_file for '$samba_share_name'..."
        if echo -e "$samba_share_config_block" | sudo tee -a "$smb_conf_file" > /dev/null; then
            echo "Samba share configuration added."
            echo "Validating Samba configuration with testparm..."
            if testparm -s; then
                echo "Samba configuration appears valid. Restarting Samba services (smbd and nmbd)..."
                run_command systemctl restart smbd
                run_command systemctl restart nmbd
                echo "Samba share '$samba_share_name' for $mount_point should be active."
            else
                echo -e "\033[31mERROR: 'testparm -s' reported issues with the Samba configuration. The new share might not work correctly.\033[0m"
                echo "The problematic entry has been added to $smb_conf_file. Please review manually."
            fi
        else
            echo -e "\033[31mERROR: Failed to append to $smb_conf_file for Samba share.\033[0m"
        fi
    fi
    if systemctl is-active --quiet smbd && systemctl is-active --quiet nmbd; then
        echo "Samba services (smbd, nmbd) are active."
    else
        echo -e "\033[33mWARNING: Samba services (smbd/nmbd) may not be active or installed.\033[0m"
    fi
else
    echo "Samba tools (smbd) not found. Skipping Samba share creation."
fi

echo -e "\n\033[1;36m========== All Steps Completed ==========\033[0m"
echo "Device processed: $device"
echo "New partition: $new_partition"
echo "Mounted at: $mount_point (UUID: $uuid)"
[ -n "$user_requested_size" ] && echo "Partition size detail: $partition_size_desc"

echo -e "\n\033[1;32mFinal Disk Layout for $device:\033[0m"
lsblk "$device" -o NAME,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINTS

echo -e "\n\033[1;32mFilesystem Usage for new mount:\033[0m"
df -h "$mount_point"

echo -e "\n\033[1;32mRelevant /etc/fstab entry:\033[0m"
grep --color=always -E "(UUID=$uuid| $mount_point )" "$fstab_file"

if command -v exportfs &>/dev/null && grep -q "^\s*${mount_point//\//\\/}[[:space:]]" "$exports_file"; then
    echo -e "\n\033[1;32mNFS Share Status for $mount_point:\033[0m"
    grep --color=always "^\s*${mount_point//\//\\/}[[:space:]]" "$exports_file"
    echo "Currently exported (filtered for this mount point):"
    exportfs -v | grep "$mount_point" || echo "(Not found in active exports, check NFS server status or logs)"
fi

if command -v smbd &>/dev/null && grep -qE "(^\[$samba_share_name\]|^\s*path\s*=\s*$escaped_mount_point_path\s*$)" "$smb_conf_file"; then
    echo -e "\n\033[1;32mSamba Share Status for '$samba_share_name' ($mount_point):\033[0m"
    grep --color=always -A6 -E "(^\[$samba_share_name\]|^\s*path\s*=\s*$escaped_mount_point_path\s*$)" "$smb_conf_file" | head -n 7
fi

echo -e "\n\033[1;36mScript finished. Please verify all configurations and test access to shares.\033[0m"
exit 0
