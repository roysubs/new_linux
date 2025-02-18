#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Install necessary tools if not already installed
apt-get update
apt-get install -y util-linux samba

# Function to mount a device
mount_device() {
  local device=$1
  local mount_point="/mnt/$(basename $device)"

  # Create mount point if it doesn't exist
  mkdir -p "$mount_point"

  # Mount the device
  mount "$device" "$mount_point"
  if [ $? -eq 0 ]; then
    echo "Mounted $device at $mount_point"
  else
    echo "Failed to mount $device"
    return 1
  fi
}

# Function to share a directory with Samba
share_directory() {
  local mount_point=$1
  local share_name=$(basename $mount_point)

  # Add the share to Samba configuration
  echo "[$share_name]
  path = $mount_point
  browseable = yes
  writable = yes
  create mask = 0777
  directory mask = 0777
  public = yes" >> /etc/samba/smb.conf

  # Restart Samba service
  systemctl restart smbd
  if [ $? -eq 0 ]; then
    echo "Shared $mount_point as $share_name via Samba"
  else
    echo "Failed to restart Samba service"
    return 1
  fi
}

# Identify all formatted devices
devices=$(lsblk -lnpo NAME,FSTYPE | awk '$2 != "" {print $1}')

# Loop through each device
for device in $devices; do
  # Check if the device is already mounted
  if ! mount | grep -q "$device"; then
    # Mount the device
    mount_device "$device"
    if [ $? -eq 0 ]; then
      # Share the mounted directory
      share_directory "/mnt/$(basename $device)"
    fi
  else
    echo "$device is already mounted"
  fi
done

echo "Script completed"
