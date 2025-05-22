#!/bin/bash

# Author: Roy Wiseman, 2025-04
# Revised by AI (Gemini) for error correction and enhanced commenting.

# ========== COMPREHENSIVE DISK PARTITIONING, MOUNTING & SHARING SCRIPT ==========
#
# This script automates the entire process of preparing a new disk or partitioning
# existing free space on a disk. It handles:
# - GPT partition table creation if needed (recommended for modern systems).
# - Creating a new primary partition (formatted as ext4) using a specified size
#   or the largest available contiguous free space on the target device.
# - Aligning the partition correctly (typically to 1MiB boundaries for performance).
# - Formatting the new partition using ext4 with performance-enhancing options
#   (lazy inode table and journal initialization).
# - Mounting the partition using its universally unique identifier (UUID) for stability.
# - Persistently adding the partition to /etc/fstab, ensuring it's available on boot,
#   with the 'nofail' option to prevent boot issues if the disk is unavailable.
# - Optionally creating Network File System (NFS) and Samba (SMB/CIFS) shares
#   for the newly mounted partition, facilitating network access.
#
# Features:
# - Root privilege check: Automatically attempts to re-run with sudo if not root.
# - Human-readable size input: Supports sizes like "5G", "100M", "0.5T" for partitions.
# - Advanced ext4 formatting: Uses 'lazy_itable_init' and 'lazy_journal_init'.
# - Kernel partition update: Includes 'partprobe' to ensure the kernel recognizes
#   new partitions immediately without a reboot.
# - Idempotency checks: Attempts to avoid duplicating entries in /etc/fstab,
#   /etc/exports (for NFS), and /etc/samba/smb.conf (for Samba).
# - Samba configuration validation: Uses 'testparm' to check Samba config syntax.
# - Detailed output: Provides step-by-step information and error messages.
# - Robust error handling: Exits on critical errors to prevent misconfiguration.
#
# USAGE:
#   sudo ./comprehensive-disk-setup.sh /dev/sdX [SIZE]
#
# ARGUMENTS:
#   /dev/sdX      Target block device (e.g., /dev/sdb, /dev/nvme0n1). MANDATORY.
#                 This is the device the script will operate on.
#   SIZE          (Optional) Desired size for the new partition.
#                 Examples: "5G" (Gigabytes), "100M" (Megabytes), "2T" (Terabytes),
#                           "500K" (Kilobytes), "0.5G".
#                 Uses IEC standard (1K = 1024 bytes).
#                 If omitted, the script will attempt to use the largest available
#                 contiguous free space block on the device.
#
# EXAMPLES:
#   # Create a 100GB partition on /dev/sdb
#   sudo ./comprehensive-disk-setup.sh /dev/sdb 100G
#
#   # Create a partition using all available free space on /dev/sdc
#   sudo ./comprehensive-disk-setup.sh /dev/sdc
#
# SAFETY:
# - ALWAYS DOUBLE-CHECK THE TARGET DEVICE (/dev/sdX) BEFORE RUNNING!
#   Incorrect device selection can lead to IRREVERSIBLE DATA LOSS.
# - This script performs disk-level operations (partitioning, formatting) and
#   requires root privileges. Use with EXTREME CAUTION.
# - It's highly recommended to run this on unmounted devices or on devices where
#   any existing data in the target free space is not needed or already backed up.
# - The script includes a safety check to prevent formatting an already mounted
#   partition that it *just* created and identified.
#
# DEPENDENCIES:
# This script relies on common Linux utilities such as:
#   bash, sudo, id, echo, grep, sed, awk,
#   lsblk, blockdev, parted, partprobe, mkfs.ext4, blkid, mount, mkdir, tee,
#   systemctl, numfmt.
# For optional sharing:
#   exportfs, systemctl (for nfs-kernel-server or nfs-server)
#   smbd, testparm, systemctl (for smbd, nmbd)
# Ensure these are installed on your system.
#
# ===================================================================================

# ---- Helper Functions ----

# Function: run_command
# Description: Executes a given command, displays it, and exits the script if the command fails.
# Arguments: The command and its arguments.
# Usage: run_command ls -l /tmp
run_command() {
    # Display the command being executed. "$*" joins all arguments into a single string for display.
    echo -e "\033[34mRunning: $*\033[0m"

    # Execute the command. "$@" expands each argument as a separate word,
    # crucial for correct and safe command execution, especially if arguments
    # contain spaces or special characters that are already appropriately quoted.
    "$@"
    local exit_code=$? # Capture exit status immediately after command execution.

    # Check if the command failed (non-zero exit code).
    if [ $exit_code -ne 0 ]; then
        # Display a detailed error message, including the exit code and the command.
        echo -e "\033[31mERROR: Command failed with exit code $exit_code: $*\033[0m"
        exit $exit_code # Exit the script on any command failure.
    fi

    # If the command was successful, return 0.
    # While the script exits on error above, returning the exit code can be useful
    # if this function were used in contexts not requiring immediate script termination.
    return $exit_code
}

# Function: convert_size_to_bytes
# Description: Converts a human-readable size string (e.g., "10G", "500M") to bytes.
#              Uses 'numfmt' for robust conversion, supporting IEC units (K, M, G, T, P).
# Arguments: $1 - The size string (e.g., "100G", "0.5T").
# Output: Prints the size in bytes to stdout. Returns 0 on success, 1 on failure.
# Example: bytes=$(convert_size_to_bytes "1G")
convert_size_to_bytes() {
    local size_in="$1" # The input size string (e.g., "5G", "100MB").
    local value_bytes  # Variable to store the converted byte value.

    # Basic input validation: Ensure input is not empty.
    if [ -z "$size_in" ]; then
        echo -e "\033[31mERROR: Size input cannot be empty.\033[0m"
        return 1 # Indicate failure.
    fi

    # Attempt to convert using numfmt.
    # --from=iec: Interprets suffixes K, M, G, T, P as powers of 1024 (KiB, MiB, GiB, etc.).
    #             Handles inputs like "1.5G", "100K", "1024B", or "1024" (as bytes).
    # 2>/dev/null: Suppress numfmt's own stderr to provide a consistent error message format.
    value_bytes=$(numfmt --from=iec "$size_in" 2>/dev/null)
    local exit_code=$? # Capture numfmt's exit code.

    # Check if numfmt failed or if its output is not a valid non-negative integer.
    # numfmt should output a whole number for byte conversions.
    if [ $exit_code -ne 0 ] || ! [[ "$value_bytes" =~ ^[0-9]+$ ]]; then
        echo -e "\033[31mERROR: Invalid size format or unable to convert '$size_in' to bytes.\033[0m"
        echo -e "\033[31m       Please use standard numbers and IEC units (e.g., '1024', '512K', '100M', '0.5G', '2T').\033[0m"
        if [ $exit_code -ne 0 ]; then
            # Provide additional diagnostic info if numfmt itself reported an error.
            echo -e "\033[31m       (numfmt utility failed with exit code $exit_code).\033[0m"
        fi
        return 1 # Indicate failure.
    fi

    # Output the converted byte value.
    echo "$value_bytes"
    return 0 # Indicate success.
}

# ---- Initial Checks and Setup ----

# Check for root privileges.
# $(id -u) returns the effective user ID. 0 is for the root user.
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[33mRoot privileges required. Rerunning with sudo...\033[0m\n"
    # Re-execute the script with sudo.
    # -E preserves the user's environment variables that might be needed (e.g., custom PATH).
    # "$0" is the path to the current script.
    # "$@" passes all original arguments to the new invocation.
    exec sudo -E "$0" "$@"
fi

echo -e "\033[1;36mStarting Comprehensive Disk Setup Script...\033[0m"

# Validate that the target device argument is provided.
if [ -z "$1" ]; then
    echo -e "\033[31mUsage: $0 /dev/sdX [Size]\033[0m"
    echo "Please specify the target block device (e.g., /dev/sdb)."
    echo "For full documentation and examples, see the script header."
    exit 1 # Exit if no device specified.
fi

device="$1"                # First argument: the target block device.
user_requested_size="$2"   # Second argument (optional): desired partition size.

# Validate if the specified device is a block device.
# -b checks if the file exists and is a block special file.
if [ ! -b "$device" ]; then
    echo -e "\033[31mERROR: Device '$device' is not a valid block device. Please verify.\033[0m"
    echo "Available block devices (excluding partitions, showing full paths):"
    # lsblk options:
    # -d: Don't print slaves or holders (shows main devices).
    # -p: Print full device paths.
    # -n: No headings.
    # -o NAME,TYPE,SIZE,MODEL: Specify output columns.
    lsblk -dpno NAME,TYPE,SIZE,MODEL
    exit 1 # Exit if not a valid block device.
fi

echo -e "\n\033[1;33mPhase 1: Device Information and Preparation\033[0m"
echo -e "Target device: \033[1;35m$device\033[0m"
# If user specified a size, display it.
[ -n "$user_requested_size" ] && echo -e "Requested partition size: \033[1;35m$user_requested_size\033[0m"

# Display current disk layout for all devices to provide context.
echo "Displaying current disk layout for all devices (run_command lsblk ...):"
run_command lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,FSTYPE,UUID,MOUNTPOINT,LABEL,MODEL

# Display detailed information for the target device.
echo "Details for target device '$device' (run_command lsblk \"$device\" ...):"
run_command lsblk "$device" -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,FSTYPE,UUID,MOUNTPOINT,LABEL,MODEL

# Determine the sector size of the target device.
# 'blockdev --getss' gets the sector size in bytes.
sector_size_bytes=$(blockdev --getss "$device")
if [ $? -ne 0 ] || ! [[ "$sector_size_bytes" =~ ^[0-9]+$ ]] || [ "$sector_size_bytes" -le 0 ]; then
    # Fallback method if blockdev fails: parse from parted output.
    echo -e "\033[33mWARNING: Could not reliably determine sector size for '$device' using blockdev. Attempting fallback with parted...\033[0m"
    # 'parted unit B print' shows info in Bytes.
    # awk extracts the logical sector size.
    sector_size_bytes=$(parted --script "$device" unit B print | awk '/Sector size \(logical\/physical\):/ {gsub(/B/,"",$3); split($3,a,"/"); print a[1]; exit}')
    if ! [[ "$sector_size_bytes" =~ ^[0-9]+$ ]] || [ "$sector_size_bytes" -le 0 ]; then
        echo -e "\033[31mERROR: Failed to determine a valid sector size for '$device' using both blockdev and parted. Exiting.\033[0m"
        exit 1 # Critical error if sector size cannot be determined.
    fi
    echo "Determined sector size (via parted fallback): $sector_size_bytes bytes"
else
    echo "Determined sector size (via blockdev): $sector_size_bytes bytes"
fi

# Ensure the disk has a GPT partition table.
echo -e "\n\033[1mStep 1.1: Checking and ensuring GPT partition table on $device...\033[0m"
# Attempt to print partition table; suppress stderr initially to check its content.
if ! parted_output=$(parted --script "$device" print 2>&1); then
    # 'parted print' failed. Check if it was due to an unrecognized disk label.
    if echo "$parted_output" | grep -qi "unrecognised disk label"; then
        echo "Unrecognised disk label on $device. Creating a new GPT partition table..."
        # 'mklabel gpt' creates a new GPT partition table, erasing existing partitions.
        run_command parted --script "$device" mklabel gpt
        echo "GPT partition table created successfully."
    else
        # 'parted print' failed for another reason.
        echo -e "\033[31mERROR: 'parted print' failed for $device for an unknown reason. Output:\033[0m"
        echo "$parted_output"
        echo "Cannot proceed safely. Please inspect the device manually."
        exit 1
    fi
elif echo "$parted_output" | grep -qi "unrecognised disk label"; then
    # This handles cases where 'parted print' might exit 0 but still output "unrecognised disk label".
    echo "Unrecognised disk label on $device (despite parted print success). Creating a new GPT partition table..."
    run_command parted --script "$device" mklabel gpt
    echo "GPT partition table created successfully."
else
    echo "Existing valid partition table found on $device."
fi
# Display the current partition layout (including free space) in sectors for calculations.
echo "Current partition layout on $device (run_command parted ... print free):"
run_command parted --script "$device" unit s print free # 'unit s' displays sizes in sectors.

# ---- Partition Creation Logic ----
echo -e "\n\033[1;33mPhase 2: Partition Definition and Creation\033[0m"
echo "Analyzing free space on $device (units in sectors)..."
# Get the partition table and free space information again, ensuring units are sectors.
# This output will be parsed by awk.
parted_free_output=$(parted --script "$device" unit s print free)
echo "$parted_free_output" # Display the raw output for transparency.

# Variables to store details of the largest identified free block.
largest_start_s=0    # Start sector of the largest free block.
largest_end_s=0      # End sector OF the free space block.
largest_size_s=0     # Size (count of sectors) in the free space block.

# Parse 'parted unit s print free' output to find the largest block of free space.
# This awk script looks for lines containing "Free Space" and extracts the numeric
# values for start, end, and size, then identifies the largest block.
# Note: Ensure standard spaces are used for indentation within the awk script string.
largest_free_block_info=$(echo "$parted_free_output" | \
    awk '
    # BEGIN block: Executed once before processing any input lines.
    # Initialize variables to track the largest free block found.
    BEGIN {
        max_size = 0;  # Largest size found so far.
        start_s = 0;   # Start sector of the largest block.
        end_s = 0;     # End sector of the largest block.
    }

    # Pattern matching: Process lines that contain the string "Free Space".
    /Free Space/ {
        current_start = ""; current_end = ""; current_size = ""; # Reset for current line.
        # Iterate through all fields ($1, $2, ..., $NF) on the current line.
        for (i = 1; i <= NF; i++) {
            # Check if the field is a number followed by "s" (e.g., "2048s").
            if ($i ~ /^[0-9]+s$/) {
                val = $i;       # Copy the field value.
                sub(/s$/, "", val); # Remove the trailing "s" to get the numeric part.

                # Assign to start, end, or size. Assumes they appear in this order.
                if (current_start == "") current_start = val;
                else if (current_end == "") current_end = val;
                else if (current_size == "") { current_size = val; break; } # Found all three.
            }
        }

        # After checking all fields, if a valid size was found for this "Free Space" line,
        # and it is larger than any previously found max_size, update tracking variables.
        # Ensure current_size is treated numerically for comparison.
        if (current_size != "" && current_size + 0 > max_size + 0) {
            max_size = current_size;
            start_s = current_start;
            end_s = current_end;
        }
    }

    # END block: Executed once after all input lines are processed.
    # If a valid free block (max_size > 0) was found, print its details.
    END {
        if (max_size > 0) {
            print start_s, end_s, max_size;
        }
    }
    ')

# Check if the primary awk script failed to find any "Free Space" segments.
if [ -z "$largest_free_block_info" ]; then
    echo -e "\033[31mERROR: No usable 'Free Space' segments found on $device by parsing parted output (primary method).\033[0m"
    echo "This can happen if the disk is entirely unallocated after 'mklabel gpt' and 'parted' output format varies."
    echo "Attempting to find the largest unallocated region directly (fallback method)..."

    # Fallback awk script: Tries to find unallocated regions if "Free Space" string isn't present
    # or if the primary method failed. This looks for lines with at least 3 fields that are
    # sector numbers, and where the 4th field (filesystem type) is empty or indicates "loop" or "free".
    # This is a heuristic for freshly initialized disks or less common parted outputs.
    # Note: Ensure standard spaces are used for indentation within the awk script string.
    largest_free_block_info=$(echo "$parted_free_output" | awk '
        BEGIN {
            max_size = 0; start_s = 0; end_s = 0;
        }

        # Process lines that:
        # 1. Have at least 3 fields (NF >= 3).
        # 2. The first three fields look like sector numbers (e.g., "2048s").
        # 3. The fourth field is empty OR its lowercase is "loop" or "free".
        #    (This tries to identify unpartitioned space or specific ignorable types).
        NF >= 3 && $1 ~ /^[0-9]+s$/ && $2 ~ /^[0-9]+s$/ && $3 ~ /^[0-9]+s$/ && \
        ($4 == "" || tolower($4) == "loop" || tolower($4) == "free") {
            current_start = $1; sub(/s$/, "", current_start);
            current_end = $2;   sub(/s$/, "", current_end);
            current_size = $3;  sub(/s$/, "", current_size);

            if (current_size + 0 > max_size + 0) {
                max_size = current_size;
                start_s = current_start;
                end_s = current_end;
            }
        }
        END {
            if (max_size > 0) {
                print start_s, end_s, max_size;
            }
        }
    ')
    if [ -z "$largest_free_block_info" ]; then
        echo -e "\033[31mERROR: Fallback method also failed to find any usable unallocated space. Please inspect '$device' manually using 'parted $device unit s print free'.\033[0m"
        exit 1 # Critical error if no free space can be identified.
    fi
    echo "Found unallocated space (fallback method): StartSector=${largest_start_s}s, EndSector=${largest_end_s}s, SizeInSectors=${largest_size_s}s"
fi

# Read the space information into separate variables.
read -r largest_start_s largest_end_s largest_size_s <<< "$largest_free_block_info"

echo "Identified largest free/unallocated block: StartSector=${largest_start_s}s, EndSector=${largest_end_s}s, SizeInSectors=${largest_size_s}s"

# Calculate alignment: Partitions should be aligned for optimal performance.
# 1MiB alignment is common (1MiB = 1048576 bytes).
sectors_for_1mib_alignment=$((1048576 / sector_size_bytes))
# Ensure at least 1 sector for alignment if 1MiB is smaller than sector size (unlikely).
sectors_for_1mib_alignment=$((sectors_for_1mib_alignment > 0 ? sectors_for_1mib_alignment : 1))

# Align the start sector: Round UP to the nearest multiple of alignment boundary.
# GPT partitions often start at sector 2048 (which is 1MiB for 512B sectors).
# Formula for rounding N up to the nearest multiple of M: ((N + M - 1) / M) * M
aligned_start_s=$(( ( (largest_start_s + sectors_for_1mib_alignment - 1) / sectors_for_1mib_alignment ) * sectors_for_1mib_alignment ))

# Ensure aligned_start_s is not before the actual start of the identified free block.
# This can happen if largest_start_s was already aligned or very small.
if [ "$aligned_start_s" -lt "$largest_start_s" ]; then
    aligned_start_s=$((aligned_start_s + sectors_for_1mib_alignment))
fi
# And ensure it's not beyond the end of the free block (partition start must be < end).
if [ "$aligned_start_s" -ge "$largest_end_s" ]; then
    echo -e "\033[31mERROR: Calculated aligned start sector ($aligned_start_s) is at or beyond the largest free block end ($largest_end_s).\033[0m"
    echo "This can happen with very small free spaces or if the free space start was already past typical alignment points. Check parted output."
    exit 1
fi
echo "Calculated aligned start sector for new partition: ${aligned_start_s}s (aligned to ${sectors_for_1mib_alignment} sectors boundary, which is 1MiB if sector size is 512B)"

# Calculate maximum usable sectors from our aligned start point within this free block.
# largest_end_s is the last sector *of* the free block.
# max_possible_sectors_from_aligned_start = (last_sector_of_block - our_aligned_start_sector) + 1 (for count)
max_possible_sectors_from_aligned_start=$((largest_end_s - aligned_start_s + 1))
if [ "$max_possible_sectors_from_aligned_start" -le 0 ]; then
    echo -e "\033[31mERROR: No space available after aligning start sector. AlignedStart: $aligned_start_s, FreeBlockEnd: $largest_end_s\033[0m"
    exit 1
fi

actual_part_end_s=""   # This will be the end sector for 'parted mkpart'.
partition_size_desc="" # For user-friendly output.
final_sector_count=0   # The actual number of sectors the new partition will have.

# Determine partition size: use user-requested size or max available.
if [ -n "$user_requested_size" ]; then
    # User specified a size.
    echo "Processing user requested size: $user_requested_size"
    requested_bytes=$(convert_size_to_bytes "$user_requested_size")
    if [ $? -ne 0 ] || [ -z "$requested_bytes" ]; then
        echo -e "\033[31mERROR: Invalid size conversion for '$user_requested_size'. Exiting.\033[0m"
        exit 1
    fi
    echo "Requested size in bytes: $requested_bytes"

    if [ "$sector_size_bytes" -le 0 ]; then # Should have been caught earlier by sector_size check.
        echo -e "\033[31mCRITICAL ERROR: Sector size ($sector_size_bytes) is zero or negative. Exiting.\033[0m"; exit 1;
    fi
    requested_sectors_count=$((requested_bytes / sector_size_bytes))
    echo "Requested size in sectors (count): $requested_sectors_count"

    if [ "$requested_sectors_count" -le 0 ]; then
        echo -e "\033[31mERROR: Requested size translates to zero or negative sectors ($requested_sectors_count). Please specify a larger size.\033[0m"; exit 1;
    fi

    # Check if requested size exceeds available space.
    if [ "$requested_sectors_count" -gt "$max_possible_sectors_from_aligned_start" ]; then
        echo -e "\033[33mWARNING: Requested size ($requested_sectors_count sectors) exceeds available space from aligned start ($max_possible_sectors_from_aligned_start sectors).\033[0m"
        echo "Using maximum available space instead."
        actual_part_end_s="$largest_end_s" # Use the end of the free block.
        final_sector_count=$max_possible_sectors_from_aligned_start
    else
        # 'parted mkpart' takes start and end sectors (inclusive).
        # So, end_sector = start_sector + count_of_sectors - 1
        actual_part_end_s=$((aligned_start_s + requested_sectors_count - 1))
        final_sector_count=$requested_sectors_count
    fi
    partition_size_desc="$user_requested_size (resolved to $final_sector_count sectors)"
else
    # No specific size requested; use all available space in the largest free block from the aligned start.
    echo "No specific size requested. Using all available space in the largest free block from aligned start."
    actual_part_end_s="$largest_end_s" # End of the free block.
    final_sector_count=$max_possible_sectors_from_aligned_start
    partition_size_desc="maximum available ($final_sector_count sectors from aligned start)"
fi

# Final safety check for partition coordinates.
if [ "$aligned_start_s" -ge "$actual_part_end_s" ]; then
    echo -e "\033[31mCRITICAL ERROR: Partition start sector ($aligned_start_s) is not less than its end sector ($actual_part_end_s).\033[0m"
    echo "This implies a partition size of zero or negative sectors. Review calculations and free space."
    echo "Largest free block was: Start=${largest_start_s}s, End=${largest_end_s}s, Size=${largest_size_s}s"
    echo "Max possible sectors from aligned start: $max_possible_sectors_from_aligned_start"
    exit 1
fi
# Ensure calculated end does not exceed the actual end of the free block.
if [ "$actual_part_end_s" -gt "$largest_end_s" ]; then # Should not happen if logic above is correct.
    echo -e "\033[31mCRITICAL ERROR: Calculated partition end sector ($actual_part_end_s) exceeds free block end ($largest_end_s).\033[0m"
    exit 1
fi

echo "Creating new partition: StartSector=${aligned_start_s}s, EndSector=${actual_part_end_s}s. Intended size: $partition_size_desc"
# 'parted mkpart':
#   --script: No interactive prompts.
#   -a optimal: Align to optimal boundaries (often 1MiB). Though we calculated alignment, this is a good safeguard.
#   mkpart primary: Creates a primary partition. Name "primary" is arbitrary for GPT, unlike MBR.
#   ext4: Sets the partition type hint in GPT. Does NOT format it.
#   ${aligned_start_s}s ${actual_part_end_s}s: Defines the partition boundaries in sectors.
run_command parted --script -a optimal "$device" mkpart primary ext4 ${aligned_start_s}s ${actual_part_end_s}s

echo "Forcing kernel to reload partition table for $device (run_command partprobe)..."
# 'partprobe' informs the OS kernel of partition table changes.
run_command partprobe "$device"
echo "Waiting a few seconds for kernel to process partition changes..."
sleep 3 # Short delay to allow kernel to update.

echo "Identifying the newly created partition on $device..."
# Robustly find the last partition created on the device.
# lsblk options:
#   -r: Raw format (no tree).
#   -n: No headings.
#   -p: Full paths (e.g., /dev/sda1).
#   -o NAME,TYPE: Output only device name and type.
# awk:
#   -v dev_pattern="^${device_escaped_for_grep}[p]?[0-9]+$": Passes shell variable as awk variable.
#     Pattern matches device names like /dev/sda1, /dev/sdd1, /dev/nvme0n1p1.
#   '$1 ~ dev_pattern && $2 == "part" {print $1}': Prints name if it matches pattern and is a partition.
# tail -n 1: Assumes the last partition listed is the new one. This is usually reliable.
device_escaped_for_grep=$(echo "$device" | sed 's/[][\/.*^$]/\\&/g') # Escape special characters in device name for grep/awk regex.
new_partition=$(lsblk -rnp -o NAME,TYPE | awk -v dev_pattern="^${device_escaped_for_grep}[p]?[0-9]+$" '$1 ~ dev_pattern && $2 == "part" {print $1}' | tail -n 1)

if [ -z "$new_partition" ]; then
    echo -e "\033[31mERROR: Failed to detect the new partition on '$device' after creation and partprobe.\033[0m"
    echo "Please check 'lsblk $device' output manually to see if the partition was created."
    lsblk "$device" # Show current state of the device for debugging.
    exit 1
fi
echo -e "New partition detected: \033[1;32m$new_partition\033[0m"

# ---- Formatting and Mounting ----
echo -e "\n\033[1;33mPhase 3: Formatting and Mounting $new_partition\033[0m"

# Safety check: Ensure the detected new partition is not already mounted.
# 'mount | grep' checks if the partition path appears at the start of a line in mount output.
if mount | grep -q "^$new_partition "; then # Space after ensures exact match (e.g. /dev/sda1 not /dev/sda10)
    echo -e "\033[31mCRITICAL ERROR: Partition '$new_partition' is ALREADY MOUNTED.\033[0m"
    echo "This script should not format an already mounted partition. Please unmount it or investigate."
    exit 1
fi

echo "Formatting $new_partition as ext4 (using -F to force, and lazy init options)..."
# 'mkfs.ext4': Creates an ext4 filesystem.
#   -F: Force operation, even if device appears to be in use or not a block device (use with caution).
#   -E lazy_itable_init=1,lazy_journal_init=1: Speeds up initial formatting by deferring
#     inode table and journal initialization to background process after first mount.
#     Useful for large partitions.
run_command mkfs.ext4 -F -E lazy_itable_init=1,lazy_journal_init=1 "$new_partition"
echo "$new_partition successfully formatted as ext4."

# Determine mount point name based on the partition name.
mount_point_basename=$(basename "$new_partition")
mount_point="/mnt/$mount_point_basename" # Standard mount point convention under /mnt.

# Create mount point directory if it doesn't exist.
# -p: Create parent directories as needed, no error if it already exists.
if [ ! -d "$mount_point" ]; then
    echo "Creating mount point directory: $mount_point..."
    run_command mkdir -p "$mount_point"
fi

echo "Retrieving UUID for $new_partition..."
# 'blkid -s UUID -o value' extracts only the UUID of the partition.
# Using UUID for mounting is more robust than device names (/dev/sdXN) which can change.
uuid=$(blkid -s UUID -o value "$new_partition")
if [ -z "$uuid" ]; then
    echo -e "\033[31mERROR: Could not retrieve UUID for '$new_partition'. This is required for fstab and mounting.\033[0m"
    exit 1
fi
echo -e "UUID for $new_partition is: \033[1;32m$uuid\033[0m"

echo "Mounting $new_partition (UUID=$uuid) at $mount_point..."
run_command mount UUID="$uuid" "$mount_point"
echo "$new_partition successfully mounted at $mount_point."

# Add entry to /etc/fstab for persistent mounting.
# fstab fields: <file system> <mount point> <type> <options> <dump> <pass>
#   UUID=$uuid: Specifies the partition by its UUID.
#   $mount_point: Where to mount it.
#   ext4: Filesystem type.
#   defaults: Default mount options (rw, suid, dev, exec, auto, nouser, async).
#   nofail: Prevents the system from halting at boot if the device is not present.
#   0: dump frequency (0 = disable).
#   2: fsck pass order (0=skip, 1=root, 2=others).
fstab_entry="UUID=$uuid $mount_point ext4 defaults,nofail 0 2"
fstab_file="/etc/fstab"

echo "Checking $fstab_file for existing entries related to UUID '$uuid' or mount point '$mount_point'..."
# Escape mount_point for grep, as it contains slashes.
escaped_mount_point_for_grep=$(echo "$mount_point" | sed 's/\//\\\//g') # \/ for /
# Check if an entry for this UUID or mount point already exists to avoid duplicates.
if grep -q -E "(UUID=$uuid| $escaped_mount_point_for_grep )" "$fstab_file"; then
    echo -e "\033[33mWARNING: An entry for UUID '$uuid' or mount point '$mount_point' appears to exist in $fstab_file. Not adding a duplicate.\033[0m"
    echo "Existing matching line(s) in $fstab_file:"
    grep --color=always -E "(UUID=$uuid| $escaped_mount_point_for_grep )" "$fstab_file"
else
    echo "Adding fstab entry to $fstab_file: $fstab_entry"
    # Using 'sudo tee -a' to append, as the script runs under sudo, but direct '>>'
    # redirection might still have permission issues in some contexts or subshells.
    # '/dev/null' discards tee's stdout copy of the entry.
    if echo "$fstab_entry" | sudo tee -a "$fstab_file" > /dev/null; then
        echo "Entry successfully added to $fstab_file."
    else
        echo -e "\033[31mERROR: Failed to append entry to $fstab_file. Manual addition might be required.\033[0m"
        # This is a significant issue for persistence.
    fi
fi

echo "Reloading systemd manager configuration to process fstab changes (run_command systemctl daemon-reexec)..."
# 'systemctl daemon-reexec' re-executes systemd manager. This is more thorough than 'daemon-reload'
# for fstab changes as it makes systemd re-evaluate mount units generated from fstab.
run_command systemctl daemon-reexec

# ---- Optional Network Sharing ----
echo -e "\n\033[1;33mPhase 4: Optional Network Sharing Setup\033[0m"

# ----- NFS Share Setup -----
exports_file="/etc/exports" # NFS server configuration file.
# Example NFS options:
#   *: Allows access from any client.
#   rw: Read-write access.
#   sync: Reply to requests only after changes have been committed to stable storage.
#   no_subtree_check: Disables subtree checking, which can improve reliability but has minor security implications.
#   all_squash: Maps all client UIDs/GIDs to the anonymous UID/GID.
#   anonuid=$(id -u): Sets anonymous UID to the current user's UID (usually the user running the script, root in this case).
#   anongid=$(id -g): Sets anonymous GID to the current user's GID.
#   Adjust these options based on security requirements. For root, files will be owned by root on the share.
nfs_share_options="*(rw,sync,no_subtree_check,all_squash,anonuid=$(id -u),anongid=$(id -g))"

echo -e "\n\033[1mAttempting to set up NFS Share (if NFS server tools are installed)...\033[0m"
# Check if 'exportfs' command (part of NFS server tools) is available.
if command -v exportfs &>/dev/null; then
    echo "NFS server tools (exportfs command) found."
    # Escape mount_point path for use in grep ERE pattern (handles slashes etc.).
    escaped_mount_point_for_grep_nfs=$(echo "$mount_point" | sed 's/[].[*^$(){}?+|/\\]/\\&/g')
    # Check if an NFS share for this mount point already exists.
    # Pattern: ^\s* (start of line, optional whitespace), then escaped mount point, then whitespace.
    if grep -q "^\s*${escaped_mount_point_for_grep_nfs}[[:space:]]" "$exports_file"; then
        echo -e "\033[33mWARNING: An NFS share for '$mount_point' seems to already exist in $exports_file. Skipping addition.\033[0m"
        echo "Existing matching line(s):"
        grep --color=always "^\s*${escaped_mount_point_for_grep_nfs}[[:space:]]" "$exports_file"
    else
        nfs_share_entry="$mount_point $nfs_share_options"
        echo "Adding NFS share entry to $exports_file: $nfs_share_entry"
        if echo "$nfs_share_entry" | sudo tee -a "$exports_file" > /dev/null; then
            echo "NFS share entry added. Re-exporting all shares (run_command exportfs -ra)..."
            # 'exportfs -ra': Re-exports all directories listed in /etc/exports.
            #                 Adds new entries, removes deleted ones, modifies existing ones.
            run_command exportfs -ra
            echo "Displaying currently active NFS exports (filtered for '$mount_point'):"
            # 'exportfs -v': Shows active exports with options. Grep for the new mount point.
            exportfs -v | grep "$mount_point" || echo "(No active export found for $mount_point, check nfs-server status or logs in /var/log/syslog or journalctl)"
            echo "NFS share for '$mount_point' has been configured."
        else
            echo -e "\033[31mERROR: Failed to append NFS share entry to $exports_file.\033[0m"
        fi
    fi
    # Check NFS server service status. Service name can vary (e.g., nfs-kernel-server, nfs-server).
    if systemctl is-active --quiet nfs-kernel-server || systemctl is-active --quiet nfs-server; then
        echo "NFS server service appears to be active."
    else
        echo -e "\033[33mINFO: NFS server service (e.g., nfs-kernel-server or nfs-server) does not seem to be active or installed.\033[0m"
        echo "If sharing doesn't work, ensure it's installed (e.g., 'sudo apt install nfs-kernel-server') and enabled ('sudo systemctl enable --now nfs-kernel-server')."
    fi
else
    echo "NFS server tools (exportfs command) not found. Skipping NFS share creation."
    echo "To enable NFS sharing, please install the appropriate NFS server package for your distribution (e.g., nfs-kernel-server on Debian/Ubuntu)."
fi

# ----- Samba Share Setup -----
smb_conf_file="/etc/samba/smb.conf" # Samba configuration file.
# Sanitize basename of the partition for use as a Samba share name.
# Keep only alphanumeric characters, underscores, and hyphens.
samba_share_name_base=$(basename "$new_partition" | sed 's/[^a-zA-Z0-9_-]//g')
samba_share_name="share_${samba_share_name_base}" # Construct a unique share name.

# Basic Samba share configuration block. Customize as needed for specific users, security.
# \n adds newlines before the block for readability in smb.conf.
#   [$samba_share_name]: The name of the share clients will see.
#   path: Filesystem path to share.
#   browseable: Whether the share is listed in network browse lists.
#   writable: Whether the share is writable (synonym: write ok = yes).
#   guest ok: Whether guest access (no password) is allowed.
#   read only = no: Equivalent to writable = yes.
#   create mask: Default permissions for new files (0664: rw-rw-r--).
#   directory mask: Default permissions for new directories (0775: rwxrwxr-x).
#   comment: A descriptive comment for the share.
samba_share_config_block="\n[$samba_share_name]\n    path = $mount_point\n    browseable = yes\n    writable = yes\n    guest ok = yes\n    read only = no\n    create mask = 0664\n    directory mask = 0775\n    comment = Auto-configured share for $mount_point\n"

echo -e "\n\033[1mAttempting to set up Samba Share (if Samba server tools are installed)...\033[0m"
# Check if 'smbd' (Samba daemon) command is available.
if command -v smbd &>/dev/null; then
    echo "Samba server tools (smbd command) found."
    # Escape mount_point path for use in grep ERE pattern.
    escaped_mount_point_path_samba=$(echo "$mount_point" | sed 's/[].[*^$(){}?+|/\\]/\\&/g')
    # Check if a Samba share with this name or for this path already exists.
    # Pattern: (^\[$samba_share_name\]) OR (^\s*path\s*=\s*$escaped_mount_point_path_samba\s*$)
    if grep -qE "(^\[$samba_share_name\]|^\s*path\s*=\s*$escaped_mount_point_path_samba\s*$)" "$smb_conf_file"; then
        echo -e "\033[33mWARNING: A Samba share named '$samba_share_name' or a share for path '$mount_point' seems to already exist in $smb_conf_file. Skipping addition.\033[0m"
        echo "Existing matching section(s) (approximate, showing section header and a few lines):"
        # Grep for the share name or path, show context (-A7) and limit lines displayed.
        grep --color=always -A7 -E "(^\[$samba_share_name\]|^\s*path\s*=\s*$escaped_mount_point_path_samba\s*$)" "$smb_conf_file" | head -n 8
    else
        echo "Adding Samba share configuration to $smb_conf_file for share name '$samba_share_name'..."
        # Append the configuration block to smb.conf.
        if echo -e "$samba_share_config_block" | sudo tee -a "$smb_conf_file" > /dev/null; then
            echo "Samba share configuration added to $smb_conf_file."
            echo "Validating Samba configuration with 'testparm -s'..."
            # 'testparm -s': Checks smb.conf syntax. '-s' suppresses prompts.
            if testparm -s; then
                echo "Samba configuration appears valid. Restarting Samba services (smbd and nmbd)..."
                # smbd: Handles file sharing and printing.
                # nmbd: Handles NetBIOS name resolution and Browse.
                run_command systemctl restart smbd
                run_command systemctl restart nmbd
                echo "Samba share '$samba_share_name' for '$mount_point' should be active."
            else
                echo -e "\033[31mERROR: 'testparm -s' reported issues with the Samba configuration after adding the new share.\033[0m"
                echo "The problematic section has been added to $smb_conf_file but might contain errors. Please review it manually. Services were NOT restarted."
            fi
        else
            echo -e "\033[31mERROR: Failed to append Samba share configuration to $smb_conf_file.\033[0m"
        fi
    fi
    # Check Samba services status.
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
if [ -n "$new_partition" ]; then # Only show partition specific info if one was created
    echo -e "New partition created: \033[1;32m$new_partition\033[0m"
    echo -e "Mounted at: \033[1;32m$mount_point\033[0m (UUID: \033[1;32m$uuid\033[0m)"
    echo -e "Partition size detail: \033[1;32m$partition_size_desc\033[0m"

    echo -e "\n\033[1;32mFinal Disk Layout for $device (lsblk \"$device\" ...):\033[0m"
    lsblk "$device" -o NAME,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINT,LABEL

    echo -e "\n\033[1;32mFilesystem Usage for new mount (df -h \"$mount_point\"):\033[0m"
    df -h "$mount_point"

    echo -e "\n\033[1;32mRelevant /etc/fstab entry (grep ... $fstab_file):\033[0m"
    grep --color=always -E "(UUID=$uuid| $escaped_mount_point_for_grep )" "$fstab_file"

    # Display NFS info if configured
    if command -v exportfs &>/dev/null && [ -n "$escaped_mount_point_for_grep_nfs" ] && \
       grep -q "^\s*${escaped_mount_point_for_grep_nfs}[[:space:]]" "$exports_file"; then
        echo -e "\n\033[1;32mNFS Share Status for $mount_point (grep ... $exports_file):\033[0m"
        grep --color=always "^\s*${escaped_mount_point_for_grep_nfs}[[:space:]]" "$exports_file"
        echo "Currently exported by NFS server (filtered for $mount_point):"
        exportfs -v | grep "$mount_point" || echo "(Share for $mount_point not found in active NFS exports. Check server logs/status.)"
    fi

    # Display Samba info if configured
    if command -v smbd &>/dev/null && [ -n "$samba_share_name" ] && [ -n "$escaped_mount_point_path_samba" ] && \
       grep -qE "(^\[$samba_share_name\]|^\s*path\s*=\s*$escaped_mount_point_path_samba\s*$)" "$smb_conf_file"; then
        echo -e "\n\033[1;32mSamba Share Status for '$samba_share_name' ($mount_point) (grep ... $smb_conf_file):\033[0m"
        grep --color=always -A7 -E "(^\[$samba_share_name\]|^\s*path\s*=\s*$escaped_mount_point_path_samba\s*$)" "$smb_conf_file" | head -n 8
    fi
else
    echo -e "\033[33mNo new partition was fully processed. Check earlier messages for errors.\033[0m"
fi

echo -e "\n\033[1;36mScript finished. Please verify all configurations and test access to any configured shares.\033[0m"
echo "Remember to adjust share permissions (e.g., 'sudo chmod -R a+rwX $mount_point' for open access, or more restrictive as needed) and security settings according to your requirements."

exit 0

# ---- Notes and Explanations from Original Script (Kept for Reference) ----
#
# Formatting options for mkfs.ext4:
# mkfs.ext4 -F -E lazy_itable_init=1,lazy_journal_init=1 -m 0 -O ^has_journal /dev/sdb1
# -F              : Force formatting even if a filesystem exists. (Used in script)
# -E lazy_* : Initialize inode and journal tables lazily. (Used in script)
# -m 0            : Reduce reserved space for root to 0%. Default is 5%.
#                   Consider for data partitions where root doesn't need emergency space.
# -O ^has_journal : Disable journaling. Can improve performance for specific workloads (e.g., temp data)
#                   but increases risk of data loss/corruption on unclean shutdown.
#                   Generally NOT recommended for data integrity. Script does NOT use this.

# Example Samba share definition from original comments (for reference, script uses a different one):
# [share_name]
# path = /mnt/sdb1
# valid users = boss
# read only = no
# browsable = yes
# guest ok = no (vs yes in script - script makes it guest accessible by default)
# create mask = 0775 (vs 0664 in script)
# directory mask = 0775 (same as script)
# comment = Added by script

# Additional Samba Settings and Explanations (from original comments):
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

# smbd vs nmbd (from original comments):
# smbd: Handles file sharing, printing, and authentication for SMB/CIFS clients.
# nmbd: Manages NetBIOS name resolution and Browse. Required if your network relies on NetBIOS.
# For most modern setups, restarting both smbd and nmbd is necessary to ensure complete functionality.
# If your network uses DNS instead of NetBIOS for name resolution, nmbd may not be strictly required,
# but is often started as part of the Samba service suite.

# Filesystem overheads (from original comments):
# Note that formatting a partition will use some space for filesystem metadata.
# e.g. formatting a small 50MB partition with ext4 might show ~40-43MB usable space.
# This overhead is due to:
# - Superblock: Contains metadata about the filesystem (size, block count, etc.).
# - Inodes: Structures used to store file metadata (permissions, ownership, pointers to data blocks).
# - Journal: If the filesystem supports journaling (e.g., ext4), space is reserved for the journal.
# - Reserved Blocks: By default, ext4 reserves ~5% of blocks for the root user to prevent
#   the system from becoming unusable if user data fills the partition. This can be adjusted (e.g., mkfs.ext4 -m 1).
#
# Example overheads shown in original:
# Size    | Usable (approx)
# --------|----------------
# 5GB     | 4.6GB
# 500MB   | 417MB
# 50MB    | 40MB
# 5MB     | 4.4MB (may warn "Filesystem too small for a journal")
