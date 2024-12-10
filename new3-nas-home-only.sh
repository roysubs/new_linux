#!/bin/bash

# Ensure we're running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run elevated (sudo)!" 1>&2
  exit 1
fi

# Detect the username of the user who invoked the script
CURRENT_USER=${SUDO_USER:-$(whoami)}

# Function to check when the last update occurred
last_update_days_ago() {
  # Get the timestamp of the last update from the apt history log
  LAST_UPDATE_TIMESTAMP=$(grep "apt-get update" /var/log/apt/history.log* 2>/dev/null | tail -n 1 | awk '{print $1, $2}')
  # If no update is found in the log, assume it's been a long time
  if [ -z "$LAST_UPDATE_TIMESTAMP" ]; then
    echo "0"  # No update found, consider it as 0 days ago
    return
  fi
  # Get the current date and compare
  CURRENT_DATE=$(date +%Y-%m-%d)
  LAST_UPDATE_DATE=$(date -d "$LAST_UPDATE_TIMESTAMP" +%Y-%m-%d)
  # Calculate the difference in days
  DIFF_DAYS=$(( ( $(date -d "$CURRENT_DATE" +%s) - $(date -d "$LAST_UPDATE_DATE" +%s) ) / 86400 ))
  echo "$DIFF_DAYS"
}

# Check how many days ago the last update was
DAYS_SINCE_LAST_UPDATE=$(last_update_days_ago)

# If the last update was more than 2 days ago, run apt-get update
if [ "$DAYS_SINCE_LAST_UPDATE" -gt 2 ]; then
  echo "It has been $DAYS_SINCE_LAST_UPDATE days since the last update. Running apt-get update..."
  apt-get update
else
  echo "Last update was $DAYS_SINCE_LAST_UPDATE days ago. No need to run apt-get update."
fi

# Install Samba if not already installed
echo "Installing Samba..."
apt-get install -y samba

# Backup existing smb.conf with a timestamp
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="/etc/samba/smb.conf-$TIMESTAMP.bak"
echo "Backing up existing Samba configuration to $BACKUP_FILE..."
cp /etc/samba/smb.conf "$BACKUP_FILE"

# Check if the Samba share already exists
if grep -q "^\[$CURRENT_USER-home\]" /etc/samba/smb.conf; then
  echo "Warning: Samba share for /home/$CURRENT_USER already exists in smb.conf. Aborting."
  echo "Edit Samba configuration:     sudo /etc/samba/smb.conf"
  echo "Restart Samba service with:   sudo systemctl restart smbd nmbd"
  exit 1
fi

# Add a Samba share for the user's home directory
USER_HOME="/home/$CURRENT_USER"
echo "Configuring Samba share for $USER_HOME..."
cat <<EOF >> /etc/samba/smb.conf

[$CURRENT_USER-home]
   path = $USER_HOME
   valid users = $CURRENT_USER
   read only = no
   browsable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   comment = Added by script
EOF

# Set the Samba password for the current user
echo "Setting Samba password for user '$CURRENT_USER'..."
smbpasswd -a "$CURRENT_USER"

# Restart Samba service to apply changes
echo "Restarting Samba service..."
systemctl restart smbd

# Enable Samba service to start on boot
echo "Enabling Samba to start on boot..."
systemctl enable smbd

# Check if ufw is active before attempting to open Samba ports
if systemctl is-active --quiet ufw; then
  echo "Opening Samba ports in the firewall (ufw is active)..."
  ufw allow samba
else
  echo "ufw is not active, skipping firewall configuration."
fi

# Provide user instructions
echo "Samba share for $USER_HOME has been configured."
echo "You can access it from Windows using '\\\\<your-debian-ip>\\$CURRENT_USER-home'."
echo "Make sure you use the username '$CURRENT_USER' and the Samba password you set."

exit 0
