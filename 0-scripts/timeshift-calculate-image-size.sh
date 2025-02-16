#!/bin/bash

# Check if running as sudo
if [ "$(id -u)" -ne 0 ]; then echo "This script must be run with sudo or as root."; exit 1; fi

# Get the list of snapshots
snapshots=$(ls /timeshift/snapshots/)

# Sort snapshots by date
oldest_snapshot=$(echo "$snapshots" | sort | head -n 1)
latest_snapshot=$(echo "$snapshots" | sort | tail -n 1)

echo "A TimeShift snapshot in rsync mode consists of inode hard links, meaning that at"
echo "creation is takes up almost zero space as the data is shared between the normal"
echo "filesystem copy and the hard link. It is only if those files are deleted in the normal"
echo "filesystem that the snapshot will be maintaining that copy and take space."
echo "This also means that 'incrementals' are not dependent upon the 'full' copy and older"
echo "copies can be deleted at any time due to the inode hard links."
echo

# Calculate size of the oldest snapshot
echo "Oldest snapshot: $oldest_snapshot"
oldest_snapshot_size=$(du -sh "/timeshift/snapshots/$oldest_snapshot" | awk '{print $1}')
echo "Apparent size of oldest snapshot: $oldest_snapshot_size"
echo "Actual usage space will be very small due to inodes."
echo

# Calculate incremental size using rsync dry-run and capture the output
echo "Snapshot: $latest_snapshot"
rsync_output=$(rsync -av --dry-run "/timeshift/snapshots/$oldest_snapshot/" "/timeshift/snapshots/$latest_snapshot/")
incremental_size_files=$(echo "$rsync_output" | grep -E '([A-Za-z0-9/]+)' | wc -l)
incremental_size_bytes=$(echo "$rsync_output" | grep -E '^[0-9]+[[:space:]]' | awk '{sum += $1} END {print sum}')
# Check if the incremental size is a valid number (non-zero)
if [[ ! "$incremental_size_bytes" =~ ^[0-9]+$ ]]; then
    echo "Invalid size calculated, skipping numfmt."
    incremental_size_human="N/A"
else
    # Convert bytes to human-readable format (KB, MB, GB)
    incremental_size_human=$(numfmt --to=iec-i --suffix=B "$incremental_size_bytes")
fi
echo "Incremental size (number of different files): $incremental_size_files"
echo "Total size of changed files: $incremental_size_human"

