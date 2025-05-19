#!/bin/bash

# Author: Roy Wiseman, 2025-04

# ========== COMPREHENSIVE DISK PARTITIONING, MOUNTING & SHARING SCRIPT ==========
#
# This script automates the entire process of preparing a new disk or partitioning
# existing free space on a disk. It handles:
# - GPT partition table creation if needed.
# - Creating a new primary partition (ext4) using specified size or largest free space.
# - Aligning the partition correctly.
# - Formatting the partition.
# - Mounting the partition using its UUID.
# - Persistently adding the partition to /etc/fstab with 'nofail' option.
# - Optionally creating NFS and Samba shares for the mounted partition.
#
# Features:
# - Root privilege check with auto-sudo elevation.
# - Supports human-readable sizes (e.g., 5G, 100M, 0.5T) for partitions.
# - Uses advanced ext4 formatting options (lazy_itable_init).
# - Includes 'partprobe' to ensure the kernel recognizes new partitions.
# - Idempotent: Checks for existing fstab, NFS, and Samba configurations
#   to avoid duplicates.
# - Validates Samba configuration using 'testparm'.
# - Provides detailed step-by-step output and error handling.
#
# USAGE:
#   sudo ./comprehensive-disk-setup.sh /dev/sdX [SIZE]
#
# ARGUMENTS:
#   /dev/sdX      Target block device (e.g., /dev/sdb, /dev/nvme0n1). MANDATORY.
#   SIZE          (Optional) Desired size for the new partition.
#                 Examples: 5G, 100M, 2T, 500K, 0.5G.
#                 If omitted, the script uses the largest available contiguous free space.
#
# EXAMPLES:
#   sudo ./comprehensive-disk-setup.sh /dev/sdb 100G
#   sudo ./comprehensive-disk-setup.sh /dev/sdc
#
# SAFETY:
# - ALWAYS DOUBLE-CHECK THE TARGET DEVICE (/dev/sdX) BEFORE RUNNING!
# - This script performs disk-level operations and requires root privileges.
#   Incorrect use can lead to data loss. Use with extreme caution.
# - It's recommended to run this on unmounted devices or devices where existing
#   data on the target free space is not needed.
# - The script checks if the newly created partition is already mounted before formatting
#   as a safety measure.
#
# ===================================================================================

# ---- Helper Functions ----

# run_command() {
#     echo -e "\033[34mRunning: $*\033[0m"
#     # Using eval can be risky if input is not strictly controlled.
#     # For this script, commands are mostly internally generated or from trusted input.
#     eval "$*"
#     local exit_code=$?
#     if [ $exit_code -ne 0 ]; then
#         echo -e "\033[31mERROR: Command failed with exit code $exit_code: $*\033[0m"
#         exit $exit_code
#     fi
#     return $exit_code
# }

run_command() {
    # Display the command. "$*" joins all arguments into a single string.
    echo -e "\033[34mRunning: $*\033[0m"

    # Execute the command. "$@" expands each argument as a separate word, crucial for correct
    # and safe command execution, especially if arguments contain spaces or special characters
    # that are already appropriately quoted.
    "$@"
    local exit_code=$?   # Capture exit status immediately after command execution.

    if [ $exit_code -ne 0 ]; then
        # Display a detailed error message, including the exit code and the command.
        # Using "$*" in the error message for a readable representation of the failed command.
        echo -e "\033[31mERROR: Command failed with exit code $exit_code: $*\033[0m"
        exit $exit_code   # Exit the script on any command failure.
    fi

    # If the command was successful, returns 0.
    # This 'return' is mostly for functions that might be called in contexts
    # where immediate exit isn't desired, but given the 'exit' above,
    # this function, as part of a script that exits on error, will only return 0.
    return $exit_code
}

# convert_size_to_bytes() {
#     local size_in="$1"
#     local size_val
#     local size_unit
#     local value_bytes
# 
#     # Normalize input to uppercase for unit matching
#     local size_upper=$(echo "$size_in" | tr 'a-z' 'A-Z')
# 
#     # Regex to capture value (integer or float) and optional unit (K,M,G,T,P) with optional B
#     if [[ ! "$size_upper" =~ ^([0-9]+(\.[0-9]+)?)([KMGTP]?B?)?$ ]]; then
#         echo -e "\033[31mERROR: Invalid size format '$size_in'. Use format like 5G, 100MB, 0.5T.\033[0m"
#         return 1
#     fi
# 
#     size_val=$(echo "$size_upper" | grep -oP '^[0-9]+(\.[0-9]+)?')
#     size_unit=$(echo "$size_upper" | grep -oP '[KMGTP]?B?$' | sed 's/B$//') # Remove trailing B
# 
#     # Using awk for floating point multiplication for precision
#     case $size_unit in
#         K) value_bytes=$(awk -v val="$size_val" 'BEGIN { print val * 1024 }') ;;
#         M) value_bytes=$(awk -v val="$size_val" 'BEGIN { print val * 1024 * 1024 }') ;;
#         G) value_bytes=$(awk -v val="$size_val" 'BEGIN { print val * 1024 * 1024 * 1024 }') ;;
#         T) value_bytes=$(awk -v val="$size_val" 'BEGIN { print val * 1024 * 1024 * 1024 * 1024 }') ;;
#         P) value_bytes=$(awk -v val="$size_val" 'BEGIN { print val * 1024 * 1024 * 1024 * 1024 * 1024 }') ;;
#         ""|B) value_bytes="$size_val" ;; # No unit or B means bytes
#         *)
#             echo -e "\033[31mERROR: Invalid size unit in '$size_in'. Supported units: K, M, G, T, P.\033[0m"
#             return 1
#             ;;
#     esac
#     # Ensure result is an integer (bytes should be whole numbers)
#     printf "%.0f\n" "$value_bytes"
#     return 0
# }

convert_size_to_bytes() {
    local size_in="$1"
    local value_bytes

    # Basic input validation: Ensure input is not empty.
    if [ -z "$size_in" ]; then
        echo -e "\033[31mERROR: Size input cannot be empty.\033[0m"
        return 1
    fi

    # Attempt to convert using numfmt.
    # --from=iec ensures KiB/MiB/GiB interpretation (1024-based) for K, M, G, etc.
    # It also handles inputs like "1.5G", "100K", "1024B", "1024" (as bytes).
    # We suppress numfmt's own stderr (2>/dev/null) to provide our own consistent error message.
    value_bytes=$(numfmt --from=iec "$size_in" 2>/dev/null)
    local exit_code=$?

    # Check if numfmt failed or if its output is not a valid positive integer.
    # numfmt should output a whole number for byte conversions.
    if [ $exit_code -ne 0 ] || ! [[ "$value_bytes" =~ ^[0-9]+$ ]]; then
        echo -e "\033[31mERROR: Invalid size format or unable to convert '$size_in' to bytes.\033[0m"
        echo -e "\033[31m       Please use standard numbers and IEC units (e.g., '1024', '512K', '100M', '0.5G', '2T').\033[0m"
        if [ $exit_code -ne 0 ]; then
            echo -e "\033[31m       (numfmt utility failed with exit code $exit_code).\033[0m"
        fi
        return 1
    fi
    
    # Output the converted byte value.
    echo "$value_bytes"
    return 0
}

# ---- Initial Checks and Setup ----

echo -e "\033[1;36mStarting Comprehensive Disk Setup Script...\033[0m"

if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[33mRoot privileges required. Rerunning with sudo...\033[0m\n"
    # Preserve environment variables that might be needed (like custom PATH for tools)
    exec sudo -E "$0" "$@"
fi

if [ -z "$1" ]; then
    echo -e "\033[31mUsage: $0 /dev/sdX [Size]\033[0m"
    echo "Please specify the target block device (e.g., /dev/sdb)."
    echo "For full documentation and examples, see the script header."
    exit 1
fi

device="$1"
user_requested_size="$2" # Optional

if [ ! -b "$device" ]; then
    echo -e "\033[31mERROR: Device '$device' is not a valid block device. Please verify.\033[0m"
    echo "Available block devices:"
    lsblk -dpno NAME,TYPE,SIZE,MODEL # -d for device, -p for full path, no headers for cleaner output
    exit 1
fi

echo -e "\n\033[1;33mPhase 1: Device Information and Preparation\033[0m"
echo "Target device: \033[1;35m$device\033[0m"
[ -n "$user_requested_size" ] && echo "Requested partition size: \033[1;35m$user_requested_size\033[0m"

echo "Displaying current disk layout for all devices (run_command lsblk ...):"
run_command lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,FSTYPE,UUID,MOUNTPOINT,LABEL,MODEL
echo "Details for target device '$device' (run_command lsblk \"$device\" ...):"
run_command lsblk "$device" -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,FSTYPE,UUID,MOUNTPOINT,LABEL,MODEL

sector_size_bytes=$(blockdev --getss "$device")
if [ $? -ne 0 ] || ! [[ "$sector_size_bytes" =~ ^[0-9]+$ ]] || [ "$sector_size_bytes" -le 0 ]; then
    echo -e "\033[33mWARNING: Could not reliably determine sector size for '$device' using blockdev. Attempting fallback with parted...\033[0m"
    sector_size_bytes=$(parted --script "$device" unit B print | awk '/Sector size \(logical\/physical\):/ {gsub(/B/,"",$3); print $3; exit}')
    if ! [[ "$sector_size_bytes" =~ ^[0-9]+$ ]] || [ "$sector_size_bytes" -le 0 ]; then
        echo -e "\033[31mERROR: Failed to determine a valid sector size for '$device' using both blockdev and parted. Exiting.\033[0m"
        exit 1
    fi
    echo "Determined sector size (via parted fallback): $sector_size_bytes bytes"
else
    echo "Determined sector size (via blockdev): $sector_size_bytes bytes"
fi

echo -e "\n\033[1mStep 1.1: Checking and ensuring GPT partition table on $device...\033[0m"
# Check if parted can print without error, then check for specific "unrecognised disk label"
if ! parted_output=$(parted --script "$device" print 2>&1); then
    if echo "$parted_output" | grep -qi "unrecognised disk label"; then
        echo "Unrecognised disk label on $device. Creating a new GPT partition table..."
        run_command parted --script "$device" mklabel gpt
        echo "GPT partition table created successfully."
    else
        echo -e "\033[31mERROR: 'parted print' failed for $device for an unknown reason. Output:\033[0m"
        echo "$parted_output"
        echo "Cannot proceed safely. Please inspect the device manually."
        exit 1
    fi
elif echo "$parted_output" | grep -qi "unrecognised disk label"; then
    # This case handles if parted print exits 0 but still reports unrecognized label in output
    echo "Unrecognised disk label on $device (despite parted print success). Creating a new GPT partition table..."
    run_command parted --script "$device" mklabel gpt
    echo "GPT partition table created successfully."
else
    echo "Existing valid partition table found on $device."
fi
echo "Current partition layout on $device (run_command parted ... print free):"
run_command parted --script "$device" unit s print free # Use sectors for subsequent calculations

# ---- Partition Creation Logic ----
echo -e "\n\033[1;33mPhase 2: Partition Definition and Creation\033[0m"
echo "Analyzing free space on $device (units in sectors)..."
parted_free_output=$(parted --script "$device" unit s print free) # Ensure we use sectors
echo "$parted_free_output"

largest_start_s=0
largest_end_s=0    # Last sector OF the free space block
largest_size_s=0   # Count of sectors in the free space block

# More robust parsing for 'Free Space' lines from 'parted unit s print free'
# Example line: "  Free Space  2048s  41943039s  41940992s" (start, end, count)
# Sometimes, if the whole disk is free after mklabel, it might not explicitly say "Free Space"
# but will list a single large unallocated block. The 'awk' approach below tries to find the largest.

# Use awk to find the largest block marked 'Free Space' or the largest unallocated block if no 'Free Space' string
# This awk script will output: start_sector end_sector size_sector
largest_free_block_info=$(echo "$parted_free_output" | \
    awk '
    BEGIN { max_size = 0; start_s = 0; end_s = 0; }
    /Free Space/ {
        # Extract numbers, assuming format "Free Space STARTs ENDs SIZEs"
        # More robustly find the numbers on the line containing "Free Space"
        current_start = ""; current_end = ""; current_size = "";
        for (i = 1; i <= NF; i++) {
            if ($i ~ /[0-9]+s$/) {
                val = $i; sub(/s$/, "", val);
                if (current_start == "") current_start = val;
                else if (current_end == "") current_end = val;
                else if (current_size == "") { current_size = val; break; }
            }
        }
        if (current_size > max_size) {
            max_size = current_size;
            start_s = current_start;
            end_s = current_end;
        }
    }
    # Fallback: if no "Free Space" string, look for unallocated blocks (often type is empty)
    # This part is more complex as parted output varies. For now, focusing on "Free Space".
    END { if (max_size > 0) print start_s, end_s, max_size; }
    ')

if [ -z "$largest_free_block_info" ]; then
    echo -e "\033[31mERROR: No usable 'Free Space' segments found on $device by parsing parted output.\033[0m"
    echo "If the disk is entirely unallocated after 'mklabel', parted might not explicitly list 'Free Space'."
    echo "Attempting to find the largest unallocated region directly..."
    # This fallback is tricky and depends heavily on parted output format for completely empty disks.
    # A common scenario: after mklabel gpt, one large unallocated block starting at 2048s.
    largest_free_block_info=$(echo "$parted_free_output" | awk '
        BEGIN { max_size = 0; start_s = 0; end_s = 0; }
        # Look for lines that are just numbers and units (e.g., "2048s  XXXXs  YYYYs")
        # and don't have a filesystem type or known partition type.
        NF >= 3 && $1 ~ /[0-9]+s$/ && $2 ~ /[0-9]+s$/ && $3 ~ /[0-9]+s$/ && ($4 == "" || $4 ~ /^(loop|free)$/i) {
            current_start = $1; sub(/s$/, "", current_start);
            current_end = $2;   sub(/s$/, "", current_end);
            current_size = $3;  sub(/s$/, "", current_size);
             if (current_size > max_size) {
                max_size = current_size;
                start_s = current_start;
                end_s = current_end;
            }
        }
        END { if (max_size > 0) print start_s, end_s, max_size; }
    ')
    if [ -z "$largest_free_block_info" ]; then
        echo -e "\033[31mERROR: Fallback method also failed to find any usable unallocated space. Please inspect '$device' manually.\033[0m"
        exit 1
    fi
    echo "Found unallocated space (fallback method): $largest_free_block_info"
fi

read -r largest_start_s largest_end_s largest_size_s <<< "$largest_free_block_info"

echo "Identified largest free/unallocated block: StartSector=${largest_start_s}s, EndSector=${largest_end_s}s, SizeInSectors=${largest_size_s}s"

# Alignment to 1MiB boundary. 1MiB = 1048576 bytes.
sectors_for_1mib_alignment=$((1048576 / sector_size_bytes))
sectors_for_1mib_alignment=$((sectors_for_1mib_alignment > 0 ? sectors_for_1mib_alignment : 1)) # Ensure at least 1

# Align start sector: round UP to the nearest multiple of alignment_boundary_sectors
# A common start for GPT is 2048s (for 512B sectors) which is 1MiB.
aligned_start_s=$(( ( (largest_start_s + sectors_for_1mib_alignment - 1) / sectors_for_1mib_alignment ) * sectors_for_1mib_alignment ))
# Ensure aligned_start_s is not before the beginning of the identified free block
if [ "$aligned_start_s" -lt "$largest_start_s" ]; then
    aligned_start_s=$((aligned_start_s + sectors_for_1mib_alignment))
fi
# And ensure it's not beyond the end of the free block
if [ "$aligned_start_s" -ge "$largest_end_s" ]; then # strictly -ge because start must be < end
    echo -e "\033[31mERROR: Calculated aligned start sector ($aligned_start_s) is at or beyond the largest free block end ($largest_end_s).\033[0m"
    echo "This can happen with very small free spaces. Check parted output."
    exit 1
fi
echo "Calculated aligned start sector for new partition: ${aligned_start_s}s (aligned to ${sectors_for_1mib_alignment} sectors boundary)"

# Max usable sectors from our aligned start point within this free block.
# The 'largest_end_s' is the last sector *of* the free block.
# The 'largest_size_s' is the *count* of sectors in that block.
# Max sectors available from our aligned start = last_sector_of_block - our_aligned_start_sector + 1
max_possible_sectors_from_aligned_start=$((largest_end_s - aligned_start_s + 1))
if [ "$max_possible_sectors_from_aligned_start" -le 0 ]; then
    echo -e "\033[31mERROR: No space available after aligning start sector. AlignedStart: $aligned_start_s, FreeBlockEnd: $largest_end_s\033[0m"
    exit 1
fi

actual_part_end_s="" # This will be the end sector for 'parted mkpart'
partition_size_desc=""

if [ -n "$user_requested_size" ]; then
    echo "Processing user requested size: $user_requested_size"
    requested_bytes=$(convert_size_to_bytes "$user_requested_size")
    if [ $? -ne 0 ] || [ -z "$requested_bytes" ]; then
        echo -e "\033[31mERROR: Invalid size conversion for '$user_requested_size'. Exiting.\033[0m"
        exit 1
    fi
    echo "Requested size in bytes: $requested_bytes"

    if [ "$sector_size_bytes" -le 0 ]; then # Should be caught earlier
         echo -e "\033[31mCRITICAL ERROR: Sector size is zero or negative. Exiting.\033[0m"; exit 1;
    fi
    requested_sectors_count=$((requested_bytes / sector_size_bytes))
    echo "Requested size in sectors (count): $requested_sectors_count"

    if [ "$requested_sectors_count" -le 0 ]; then
        echo -e "\033[31mERROR: Requested size translates to zero or negative sectors ($requested_sectors_count). Please specify a larger size.\033[0m"; exit 1;
    fi

    if [ "$requested_sectors_count" -gt "$max_possible_sectors_from_aligned_start" ]; then
        echo -e "\033[33mWARNING: Requested size ($requested_sectors_count sectors) exceeds available space from aligned start ($max_possible_sectors_from_aligned_start sectors).\033[0m"
        echo "Using maximum available space instead."
        actual_part_end_s="$largest_end_s" # Use the end of the free block
        final_sector_count=$max_possible_sectors_from_aligned_start
    else
        # 'parted mkpart' takes start and end sectors (inclusive).
        # So, end_sector = start_sector + count_of_sectors - 1
        actual_part_end_s=$((aligned_start_s + requested_sectors_count - 1))
        final_sector_count=$requested_sectors_count
    fi
    partition_size_desc="$user_requested_size (resolved to $final_sector_count sectors)"
else
    echo "No specific size requested. Using all available space in the largest free block from aligned start."
    actual_part_end_s="$largest_end_s"
    final_sector_count=$max_possible_sectors_from_aligned_start
    partition_size_desc="maximum available ($final_sector_count sectors)"
fi

# Final safety check for partition coordinates
if [ "$aligned_start_s" -ge "$actual_part_end_s" ]; then
    echo -e "\033[31mCRITICAL ERROR: Partition start sector ($aligned_start_s) is not less than its end sector ($actual_part_end_s).\033[0m"
    echo "This implies a partition size of zero or negative sectors. Review calculations and free space."
    exit 1
fi
if [ "$actual_part_end_s" -gt "$largest_end_s" ]; then # Should not happen if logic above is correct
    echo -e "\033[31mCRITICAL ERROR: Calculated partition end sector ($actual_part_end_s) exceeds free block end ($largest_end_s).\033[0m"
    exit 1
fi


echo "Creating new partition: StartSector=${aligned_start_s}s, EndSector=${actual_part_end_s}s. Intended size: $partition_size_desc"
# Use -a optimal for parted to ensure alignment if our calculation wasn't perfect, though we aim for it.
run_command parted --script -a optimal "$device" mkpart primary ext4 ${aligned_start_s}s ${actual_part_end_s}s

echo "Forcing kernel to reload partition table for $device (run_command partprobe)..."
run_command partprobe "$device"
echo "Waiting a few seconds for kernel to process partition changes..."
sleep 3 # Increased sleep slightly

echo "Identifying the newly created partition on $device..."
# Robustly find the last partition created on the device.
# lsblk -rnp: raw, no-headings, full-paths. -o NAME,TYPE: get name and type.
# awk: filter for lines where $1 matches pattern like /dev/sdXN or /dev/nvmeXnYNpN and $2 is "part".
device_escaped_for_grep=$(echo "$device" | sed 's/[][\/.*^$]/\\&/g') # Escape special characters for grep
new_partition=$(lsblk -rnp -o NAME,TYPE | awk -v dev_pattern="^${device_escaped_for_grep}[p]?[0-9]+$" '$1 ~ dev_pattern && $2 == "part" {print $1}' | tail -n 1)

if [ -z "$new_partition" ]; then
    echo -e "\033[31mERROR: Failed to detect the new partition on '$device' after creation and partprobe.\033[0m"
    echo "Please check 'lsblk $device' output manually to see if the partition was created."
    lsblk "$device"
    exit 1
fi
echo "New partition detected: \033[1;32m$new_partition\033[0m"

# ---- Formatting and Mounting ----
echo -e "\n\033[1;33mPhase 3: Formatting and Mounting $new_partition\033[0m"

# Safety check: Ensure the detected new partition is not already mounted
if mount | grep -q "^$new_partition "; then # Check for exact match followed by space
    echo -e "\033[31mCRITICAL ERROR: Partition '$new_partition' is ALREADY MOUNTED.\033[0m"
    echo "This script should not format an already mounted partition. Please unmount it or investigate."
    exit 1
fi

echo "Formatting $new_partition as ext4 (using -F to force, and lazy init options)..."
# -F: Force mke2fs to run, even if the specified device is not a block special device, or appears to be in use.
run_command mkfs.ext4 -F -E lazy_itable_init=1,lazy_journal_init=1 "$new_partition"
echo "$new_partition successfully formatted as ext4."

mount_point_basename=$(basename "$new_partition")
mount_point="/mnt/$mount_point_basename" # Standard mount point under /mnt

if [ ! -d "$mount_point" ]; then
    echo "Creating mount point directory: $mount_point..."
    run_command mkdir -p "$mount_point"
fi

echo "Retrieving UUID for $new_partition..."
uuid=$(blkid -s UUID -o value "$new_partition")
if [ -z "$uuid" ]; then
    echo -e "\033[31mERROR: Could not retrieve UUID for '$new_partition'. This is required for fstab and mounting.\033[0m"
    exit 1
fi
echo "UUID for $new_partition is: \033[1;32m$uuid\033[0m"

echo "Mounting $new_partition (UUID=$uuid) at $mount_point..."
run_command mount UUID="$uuid" "$mount_point"
echo "$new_partition successfully mounted at $mount_point."

fstab_entry="UUID=$uuid $mount_point ext4 defaults,nofail 0 2"
fstab_file="/etc/fstab"
echo "Checking $fstab_file for existing entries related to UUID '$uuid' or mount point '$mount_point'..."
# Escape mount_point for grep, as it contains slashes
escaped_mount_point_for_grep=$(echo "$mount_point" | sed 's/\//\\\//g')
if grep -q -E "(UUID=$uuid| $escaped_mount_point_for_grep )" "$fstab_file"; then
    echo -e "\033[33mWARNING: An entry for UUID '$uuid' or mount point '$mount_point' appears to exist in $fstab_file. Not adding a duplicate.\033[0m"
    echo "Existing matching line(s) in $fstab_file:"
    grep --color=always -E "(UUID=$uuid| $escaped_mount_point_for_grep )" "$fstab_file"
else
    echo "Adding fstab entry to $fstab_file: $fstab_entry"
    # Using sudo tee to append, as the script is already running under sudo but direct '>>' might have issues
    if echo "$fstab_entry" | sudo tee -a "$fstab_file" > /dev/null; then
        echo "Entry successfully added to $fstab_file."
    else
        echo -e "\033[31mERROR: Failed to append entry to $fstab_file. Manual addition might be required.\033[0m"
        # This is a significant issue for persistence.
    fi
fi

echo "Reloading systemd manager configuration to process fstab changes (run_command systemctl daemon-reexec)..."
run_command systemctl daemon-reexec # More thorough than daemon-reload for fstab changes

# ---- Optional Network Sharing ----
echo -e "\n\033[1;33mPhase 4: Optional Network Sharing Setup\033[0m"

# NFS Share Setup
exports_file="/etc/exports"
# Example NFS options: make current user the owner of files on share. Adjust as needed.
nfs_share_options="*(rw,sync,no_subtree_check,all_squash,anonuid=$(id -u),anongid=$(id -g))"

echo -e "\n\033[1mAttempting to set up NFS Share (if NFS server tools are installed)...\033[0m"
if command -v exportfs &>/dev/null; then
    echo "NFS server tools (exportfs command) found."
    # Escape mount_point for grep pattern (contains slashes)
    escaped_mount_point_for_grep_nfs=$(echo "$mount_point" | sed 's/[].[*^$(){}?+|/\\]/\\&/g')
    if grep -q "^\s*${escaped_mount_point_for_grep_nfs}[[:space:]]" "$exports_file"; then
        echo -e "\033[33mWARNING: An NFS share for '$mount_point' seems to already exist in $exports_file. Skipping addition.\033[0m"
        echo "Existing matching line(s):"
        grep --color=always "^\s*${escaped_mount_point_for_grep_nfs}[[:space:]]" "$exports_file"
    else
        nfs_share_entry="$mount_point $nfs_share_options"
        echo "Adding NFS share entry to $exports_file: $nfs_share_entry"
        if echo "$nfs_share_entry" | sudo tee -a "$exports_file" > /dev/null; then
            echo "NFS share entry added. Re-exporting all shares (run_command exportfs -ra)..."
            run_command exportfs -ra # Reloads all exports from /etc/exports
            echo "Displaying currently active NFS exports (filtered for '$mount_point'):"
            exportfs -v | grep "$mount_point" || echo "(No active export found for $mount_point, check nfs-server status or logs)"
            echo "NFS share for '$mount_point' has been configured."
        else
             echo -e "\033[31mERROR: Failed to append NFS share entry to $exports_file.\033[0m"
        fi
    fi
    # Check NFS server status
    if systemctl is-active --quiet nfs-kernel-server || systemctl is-active --quiet nfs-server; then
        echo "NFS server service appears to be active."
    else
        echo -e "\033[33mINFO: NFS server service (e.g., nfs-kernel-server) does not seem to be active or installed.\033[0m"
        echo "If sharing doesn't work, ensure it's installed (e.g., 'sudo apt install nfs-kernel-server') and enabled ('sudo systemctl enable --now nfs-kernel-server')."
    fi
else
    echo "NFS server tools (exportfs command) not found. Skipping NFS share creation."
    echo "To enable NFS sharing, please install the appropriate NFS server package for your distribution (e.g., nfs-kernel-server on Debian/Ubuntu)."
fi

# Samba Share Setup
smb_conf_file="/etc/samba/smb.conf"
# Sanitize basename for share name (alphanumeric, underscore, hyphen)
samba_share_name_base=$(basename "$new_partition" | sed 's/[^a-zA-Z0-9_-]//g')
samba_share_name="share_${samba_share_name_base}" # Construct share name

# Basic Samba share configuration block. Customize as needed (e.g., for specific users, security).
samba_share_config_block="\n[$samba_share_name]\n   path = $mount_point\n   browseable = yes\n   writable = yes\n   guest ok = yes\n   read only = no\n   create mask = 0664\n   directory mask = 0775\n   comment = Auto-configured share for $mount_point\n"

echo -e "\n\033[1mAttempting to set up Samba Share (if Samba server tools are installed)...\033[0m"
if command -v smbd &>/dev/null; then
    echo "Samba server tools (smbd command) found."
    # Escape mount_point path for use in grep ERE pattern
    escaped_mount_point_path_samba=$(echo "$mount_point" | sed 's/[].[*^$(){}?+|/\\]/\\&/g')
    # Check for existing share by name or by path
    if grep -qE "(^\[$samba_share_name\]|^\s*path\s*=\s*$escaped_mount_point_path_samba\s*$)" "$smb_conf_file"; then
        echo -e "\033[33mWARNING: A Samba share named '$samba_share_name' or a share for path '$mount_point' seems to already exist in $smb_conf_file. Skipping addition.\033[0m"
        echo "Existing matching section(s) (approximate):"
        grep --color=always -A7 -E "(^\[$samba_share_name\]|^\s*path\s*=\s*$escaped_mount_point_path_samba\s*$)" "$smb_conf_file" | head -n 8
    else
        echo "Adding Samba share configuration to $smb_conf_file for share name '$samba_share_name'..."
        if echo -e "$samba_share_config_block" | sudo tee -a "$smb_conf_file" > /dev/null; then
            echo "Samba share configuration added to $smb_conf_file."
            echo "Validating Samba configuration with 'testparm -s'..."
            if testparm -s; then # Checks smb.conf syntax
                echo "Samba configuration appears valid. Restarting Samba services (smbd and nmbd)..."
                run_command systemctl restart smbd
                run_command systemctl restart nmbd # Corrected typo from original c001.sh
                echo "Samba share '$samba_share_name' for '$mount_point' should be active."
            else
                echo -e "\033[31mERROR: 'testparm -s' reported issues with the Samba configuration after adding the new share.\033[0m"
                echo "The problematic section has been added to $smb_conf_file. Please review it manually. Services were not restarted."
            fi
        else
            echo -e "\033[31mERROR: Failed to append Samba share configuration to $smb_conf_file.\033[0m"
        fi
    fi
    # Check Samba services status
    if systemctl is-active --quiet smbd && systemctl is-active --quiet nmbd; then
        echo "Samba services (smbd, nmbd) appear to be active."
    else
        echo -e "\033[33mINFO: Samba services (smbd and/or nmbd) do not seem to be active or installed.\033[0m"
        echo "If sharing doesn't work, ensure Samba is installed (e.g., 'sudo apt install samba') and services are enabled ('sudo systemctl enable --now smbd nmbd')."
    fi
else
    echo "Samba server tools (smbd command) not found. Skipping Samba share creation."
    echo "To enable Samba sharing, please install the Samba package for your distribution (e.g., samba on Debian/Ubuntu)."
fi

# ---- Final Summary ----
echo -e "\n\033[1;36m========== All Steps Completed ==========\033[0m"
echo -e "Device processed: \033[1;35m$device\033[0m"
echo -e "New partition created: \033[1;32m$new_partition\033[0m"
echo -e "Mounted at: \033[1;32m$mount_point\033[0m (UUID: \033[1;32m$uuid\033[0m)"
echo -e "Partition size detail: \033[1;32m$partition_size_desc\033[0m"

echo -e "\n\033[1;32mFinal Disk Layout for $device (lsblk \"$device\" ...):\033[0m"
lsblk "$device" -o NAME,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINT,LABEL

echo -e "\n\033[1;32mFilesystem Usage for new mount (df -h \"$mount_point\"):\033[0m"
df -h "$mount_point"

echo -e "\n\033[1;32mRelevant /etc/fstab entry (grep ... $fstab_file):\033[0m"
grep --color=always -E "(UUID=$uuid| $escaped_mount_point_for_grep )" "$fstab_file"

if command -v exportfs &>/dev/null && grep -q "^\s*${escaped_mount_point_for_grep_nfs}[[:space:]]" "$exports_file"; then
    echo -e "\n\033[1;32mNFS Share Status for $mount_point (grep ... $exports_file):\033[0m"
    grep --color=always "^\s*${escaped_mount_point_for_grep_nfs}[[:space:]]" "$exports_file"
    echo "Currently exported by NFS server (filtered):"
    exportfs -v | grep "$mount_point" || echo "(Share for $mount_point not found in active NFS exports. Check server logs/status.)"
fi

if command -v smbd &>/dev/null && grep -qE "(^\[$samba_share_name\]|^\s*path\s*=\s*$escaped_mount_point_path_samba\s*$)" "$smb_conf_file"; then
    echo -e "\n\033[1;32mSamba Share Status for '$samba_share_name' ($mount_point) (grep ... $smb_conf_file):\033[0m"
    grep --color=always -A7 -E "(^\[$samba_share_name\]|^\s*path\s*=\s*$escaped_mount_point_path_samba\s*$)" "$smb_conf_file" | head -n 8
fi

echo -e "\n\033[1;36mScript finished. Please verify all configurations and test access to any configured shares.\033[0m"
echo "Remember to adjust share permissions and security settings according to your needs."

exit 0






# Format the partition
# lazy_itable_init / lazy_journal_init will run those after the initial format
# mkfs.ext4 -F -E lazy_itable_init=1,lazy_journal_init=1 -m 0 -O ^has_journal /dev/sdb1
# -F              : Force formatting even if a filesystem exists.
# -E lazy_*       : Initialize inode and journal tables lazily (after the initial format completes).
# -m 0            : Reduce reserved space to 0%.
# -O ^has_journal : Skip journaling.


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
