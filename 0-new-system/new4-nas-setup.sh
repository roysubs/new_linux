#!/bin/bash

# Ensure we're running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run elevated (sudo)!" 1>&2
  exit 1
fi

# Check if Samba is installed by verifying if the smb.conf file exists
if [ ! -f /etc/samba/smb.conf ]; then
  echo "Samba configuration file (/etc/samba/smb.conf) not found. Installing Samba..."
  if command -v apt &> /dev/null; then
    sudo apt update && sudo apt install -y samba
  else
    echo "Unsupported package manager. Exiting."
    exit 1
  fi
  # Recheck if the smb.conf file exists after installation
  if [ ! -f /etc/samba/smb.conf ]; then
    echo "Samba configuration file (/etc/samba/smb.conf) still not found. Samba installation failed."
    exit 1
  fi
fi

# Function to display device info
display_device_info() {
  echo "Displaying device information..."
  for device in $(lsblk -lnpo NAME,SIZE,FSTYPE,MOUNTPOINT | grep -v "swap"); do
    NAME=$(echo $device | awk '{print $1}')
    SIZE=$(echo $device | awk '{print $2}')
    FSTYPE=$(echo $device | awk '{print $3}')
    MOUNTPOINT=$(echo $device | awk '{print $4}')
    MOUNT_STATUS="No"
    if [ -n "$MOUNTPOINT" ]; then
      MOUNT_STATUS="Yes, at $MOUNTPOINT"
    fi
    SMB_SHARE="No"
    if grep -q "$NAME" /etc/samba/smb.conf; then
      SMB_SHARE="Yes"
    fi
    echo "$NAME - Size: $SIZE - FS: $FSTYPE - Mounted: $MOUNT_STATUS"
    echo "  Samba share: $SMB_SHARE"
  done
}

# Display initial system state
echo "Initial system state:"
display_device_info

# Mount unmounted partitions
echo "Detecting and mounting unmounted partitions..."
for PARTITION in $(lsblk -lnpo NAME,TYPE,FSTYPE | grep "part" | awk '{print $1,$3}'); do
  PARTITION_NAME=$(echo $PARTITION | awk '{print $1}')
  PARTITION_FS=$(echo $PARTITION | awk '{print $2}')

  # Skip partitions without a valid filesystem
  if [[ "$PARTITION_FS" == "swap" || -z "$PARTITION_FS" ]]; then
    echo "$PARTITION_NAME has an unsupported filesystem type. Skipping."
    continue
  fi

  # Check if the partition is already mounted
  if ! mount | grep -q "$PARTITION_NAME"; then
    MOUNT_POINT="/mnt/$(basename "$PARTITION_NAME")"
    echo "Mounting $PARTITION_NAME to $MOUNT_POINT..."
    mkdir -p "$MOUNT_POINT"
    mount "$PARTITION_NAME" "$MOUNT_POINT"
    if [ $? -ne 0 ]; then
      echo "Failed to mount $PARTITION_NAME. Skipping."
      continue
    fi
    # Add to fstab for persistence
    echo "$PARTITION_NAME $MOUNT_POINT auto defaults 0 0" >> /etc/fstab
  else
    echo "$PARTITION_NAME is already mounted."
  fi
done

# Backup existing Samba configuration
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="/etc/samba/smb.conf-$TIMESTAMP.bak"
echo "Backing up existing Samba configuration to $BACKUP_FILE..."
cp /etc/samba/smb.conf "$BACKUP_FILE"

# Add Samba shares for each mount point
echo "Configuring Samba shares for mounted partitions..."
for MOUNT_POINT in $(lsblk -lnpo MOUNTPOINT | grep "/mnt/"); do
  SHARE_NAME=$(basename "$MOUNT_POINT")
  if ! grep -q "^\[$SHARE_NAME\]" /etc/samba/smb.conf; then
    echo "Adding Samba share for $MOUNT_POINT..."
    cat <<EOF >> /etc/samba/smb.conf

[$SHARE_NAME]
   path = $MOUNT_POINT
   browseable = yes
   read only = no
   guest ok = yes
EOF
  else
    echo "Samba share for $MOUNT_POINT already exists."
  fi
done

# Restart Samba service to apply changes
echo "Restarting Samba service..."
systemctl restart smbd

# Enable Samba service to start on boot
echo "Enabling Samba service to start on boot..."
systemctl enable smbd

# Check if ufw is active and configure firewall
if systemctl is-active --quiet ufw; then
  echo "Configuring firewall to allow Samba traffic..."
  ufw allow samba
else
  echo "Firewall (ufw) is not active, skipping firewall configuration."
fi

# Display system state after changes
echo "System state after changes:"
display_device_info

echo "Samba shares have been configured. Access them using '\\<your-debian-ip>\\<share-name>'."
echo "Edit Samba configuration:     sudo /etc/samba/smb.conf"
echo "Restart Samba service with:   sudo systemctl restart smbd nmbd"

