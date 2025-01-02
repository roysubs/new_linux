#!/bin/bash

# Script to partition, format, and mount unpartitioned space on all drives.

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then 
  echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
  sudo "$0" "$@"
  exit 0
fi

# Discover and enumerate all disk devices
DISKS=$(lsblk -dn -o NAME,TYPE | awk '$2=="disk" {print $1}')

if [ -z "$DISKS" ]; then
  echo "No disk devices found. Exiting."
  exit 1
fi

# Minimum size for unallocated space to be considered (in MB)
MIN_SIZE_MB=100

# Function to check and report on partitions and mountpoints
function check_disk_info {
  local disk=$1
  echo -e "\nDevice: /dev/$disk"
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINT /dev/$disk

  # Report unpartitioned space
  unallocated_space=$(parted /dev/$disk unit MB print free | awk '/Free Space/ {print $1, $2, $3, $4}')
  local eligible_space=false

  if [ -z "$unallocated_space" ]; then
    echo "No unallocated space available."
  else
    echo -e "Unallocated space:"
    echo "$unallocated_space" | while read -r start end size unit; do
      size_mb=$(echo "$size" | sed 's/MB$//')
      if (( $(echo "$size_mb >= $MIN_SIZE_MB" | bc -l) )); then
        echo "Cylinder Start: $start, Cylinder End: $end, Size: $size (Eligible for partitioning)"
        eligible_space=true
      else
        echo "Cylinder Start: $start, Cylinder End: $end, Size: $size (Gap space does not meet $MIN_SIZE_MB MB threshold to consider partitioning)"
      fi
    done
  fi

  echo $eligible_space
}

# Function to partition and mount unpartitioned space
function partition_and_mount {
  local disk=$1
  local mount_base="/mnt/nfs-share"

  echo -e "\nPartitioning /dev/$disk..."
  parted /dev/$disk --script mklabel gpt
  parted /dev/$disk --script mkpart primary ext4 0% 100%

  # Get the new partition name
  local partition="/dev/${disk}1"

  echo "Formatting $partition as ext4..."
  mkfs.ext4 $partition

  # Create mount points
  local normal_mount="/mnt/$disk"
  local nfs_mount="$mount_base/$disk"

  mkdir -p $normal_mount
  mkdir -p $nfs_mount

  # Mount the partition
  mount $partition $normal_mount
  mount --bind $normal_mount $nfs_mount

  # Add to /etc/fstab
  echo "$partition $normal_mount ext4 defaults,nofail 0 0" >> /etc/fstab
  echo "$normal_mount $nfs_mount none bind,nofail 0 0" >> /etc/fstab

  echo "Partition $partition has been created, formatted, and mounted at $normal_mount and $nfs_mount."
}

# Main logic
for disk in $DISKS; do
  echo "Checking disk /dev/$disk..."
  eligible=$(check_disk_info $disk)

  if [[ "$eligible" == true ]]; then
    read -p "Would you like to partition and mount all unpartitioned space on /dev/$disk? (y/n): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
      partition_and_mount $disk
    else
      echo "Skipping /dev/$disk."
    fi
  else
    echo "Summary for /dev/$disk:" >&2
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT /dev/$disk >&2
    echo "All gaps identified on /dev/$disk:" >&2
    parted /dev/$disk unit MB print free | awk '/Free Space/ {print "  Cylinder Start: "$1", Cylinder End: "$2", Size: "$3}' >&2
    echo "No eligible unpartitioned space found. Skipping." >&2
  fi

done

echo -e "\nOperation complete. Remember to run 'systemctl daemon-reload' if necessary."

