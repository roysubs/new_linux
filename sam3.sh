#!/bin/bash

# Require root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo "$0" "$@"
fi

set -e
CURRENT_USER=${SUDO_USER:-$(whoami)}
SHARE_DIR="/mnt/shares"

# Install Samba if missing
if ! dpkg -l | grep -q samba; then
    echo "Installing Samba..."
    apt-get install -y samba
fi

# Ensure the share directory exists
mkdir -p "$SHARE_DIR"
chown "$CURRENT_USER:$CURRENT_USER" "$SHARE_DIR"
chmod 777 "$SHARE_DIR"

# Find all relevant drives
ROOT_DEVICE=$(findmnt -n -o SOURCE /)
lsblk -lnpo NAME,MOUNTPOINT | grep -E '/dev/sd[a-z][0-9]?' | while read -r DEV_NAME MOUNTPOINT; do
    MOUNT_NAME=$(basename "$DEV_NAME")
    MOUNT_TARGET="$SHARE_DIR/$MOUNT_NAME"
    
    if [ "$DEV_NAME" == "$ROOT_DEVICE" ]; then
        echo "Skipping $DEV_NAME as it is the root partition."
        continue
    fi
    
    echo "Processing $DEV_NAME -> $MOUNT_TARGET"
    mkdir -p "$MOUNT_TARGET"
    
    if [ -z "$MOUNTPOINT" ]; then
        echo "Mounting $DEV_NAME at $MOUNT_TARGET"
        mount "$DEV_NAME" "$MOUNT_TARGET" || {
            echo -e "\033[31mFailed to mount $DEV_NAME. Exiting...\033[0m"
            exit 1
        }
    fi
    
    echo "Setting ownership and permissions for $MOUNT_TARGET"
    chown -R "$CURRENT_USER:$CURRENT_USER" "$MOUNT_TARGET"
    chmod -R 777 "$MOUNT_TARGET"

done

# Backup and update smb.conf
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
cp /etc/samba/smb.conf "/etc/samba/smb.conf-$TIMESTAMP.bak"

echo "Updating Samba configuration..."
cat <<EOF > /etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   server string = Samba Server
   security = user
   map to guest = Bad User
   dns proxy = no

[shares]
   path = $SHARE_DIR
   read only = no
   guest ok = yes
   force user = $CURRENT_USER
   create mask = 0777
   directory mask = 0777
EOF

# Restart and enable Samba
systemctl restart smbd
systemctl enable smbd

# Set Samba password
echo "Setting Samba password for $CURRENT_USER..."
smbpasswd -a "$CURRENT_USER"

echo "Samba is now set up. Connect to \\$HOSTNAME\shares from your network."

