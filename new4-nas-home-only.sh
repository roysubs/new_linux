#!/bin/bash

# Function to convert human-readable sizes (e.g., 1K, 1M, 1G, 1T) to bytes
convert_to_bytes() {
    SIZE=$1
    VALUE=$(echo "$SIZE" | sed -E 's/[^0-9.]//g')   # Extract the numeric part, including decimals
    UNIT=$(echo "$SIZE" | sed -E 's/[0-9.]*//g')    # Extract the unit (e.g., T, G, M, K)
    case "$UNIT" in
        T) MULTIPLIER=$((1024 * 1024 * 1024 * 1024)) ;;  # Tebibytes
        G) MULTIPLIER=$((1024 * 1024 * 1024)) ;;         # Gibibytes
        M) MULTIPLIER=$((1024 * 1024)) ;;                # Mebibytes
        K) MULTIPLIER=$((1024)) ;;                       # Kibibytes
        *) MULTIPLIER=1 ;;                               # Default to bytes
    esac
    # Calculate the size in bytes (VALUE * MULTIPLIER), forcing an integer result
    BYTES=$(echo "$VALUE * $MULTIPLIER" | bc | awk '{printf "%.0f", $0}')
    echo "$BYTES"
}

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo "$0" "$@"
fi

set -e

# Detect the username of the user who invoked the script
CURRENT_USER=${SUDO_USER:-$(whoami)}

### Update: Install Samba only if not already installed
if ! dpkg -l | grep -q samba; then
    echo "Installing Samba..."
    apt-get install -y samba
else
    echo "Samba is already installed."
fi

# Backup existing smb.conf with a timestamp
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="/etc/samba/smb.conf-$TIMESTAMP.bak"
echo "Backing up existing Samba configuration to $BACKUP_FILE..."
cp /etc/samba/smb.conf "$BACKUP_FILE"

USER_HOME="/home/$CURRENT_USER"
USER_SMB="home-$CURRENT_USER"

# Check if the Samba share for user already exists
if grep -q "^\[$USER_SMB\]" /etc/samba/smb.conf; then
    echo "Samba share for /home/$CURRENT_USER already exists. Skipping..."
else
    # Add a Samba share for the user's home directory
    echo "Configuring Samba share for $USER_HOME..."
    cat <<EOF >> /etc/samba/smb.conf

[$USER_SMB]
   path = $USER_HOME
   valid users = $CURRENT_USER
   read only = no
   browsable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   comment = Added by script
EOF
fi

# Iterate over potential big devices (sda1, sdb1, sdc1, sdd1)
NAS_COUNTER=1
lsblk -lnpo NAME,SIZE,MOUNTPOINT | grep -E '/dev/sd[a-d][1-9]' | while read -r DEV_NAME DEV_SIZE MOUNTPOINT; do
    echo "DEV_NAME=$DEV_NAME"
    echo "DEV_SIZE=$DEV_SIZE"
    echo "MOUNTPOINT=$MOUNTPOINT"

    # Convert size to bytes for comparison
    DEV_SIZE_BYTES=$(convert_to_bytes "$DEV_SIZE")
    echo "DEV_SIZE_BYTES=$DEV_SIZE_BYTES"

    # Ignore small devices (less than 1GB)
    if [ "$DEV_SIZE_BYTES" -lt 1073741824 ]; then
        continue
    fi

    # NAS_NAME="nas$NAS_COUNTER"
    NAS_NAME=$(echo "$DEVICE" | sed 's|/dev/|nas-|')
    COMMENT="Added by script, $DEV_NAME, $DEV_SIZE"

    # Add Samba share (example)
    echo "Adding Samba share for $DEV_NAME ($NAS_NAME)..."

    NAS_COUNTER=$((NAS_COUNTER + 1))

    # Check if the share already exists in smb.conf
    if grep -q "^\[$NAS_NAME\]" /etc/samba/smb.conf; then
        echo "Samba share for $DEV_NAME ($NAS_NAME) already exists. Skipping..."
    else
        # Add a Samba share for the partition
        echo "Adding Samba share for $DEV_NAME ($NAS_NAME)..."
        cat <<EOF >> /etc/samba/smb.conf

[$NAS_NAME]
   path = $MOUNTPOINT
   valid users = $CURRENT_USER
   read only = no
   browsable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   comment = $COMMENT
EOF
    fi

    # If this is the root partition (/dev/sda1), make it read-only
    if [ "$DEV_NAME" == "/dev/sda1" ]; then
        ROOT_SHARE="nas${NAS_COUNTER}-root"
        if ! grep -q "^\[$ROOT_SHARE\]" /etc/samba/smb.conf; then
            echo "Adding Samba root share for $ROOT_SHARE..."
            cat <<EOF >> /etc/samba/smb.conf

[$ROOT_SHARE]
   path = /
   valid users = root
   read only = yes
   browsable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   comment = Root partition - Read only
EOF
        fi
    fi

    NAS_COUNTER=$((NAS_COUNTER + 1))
done

# Set the Samba password for the current user
echo "Setting Samba password for user '$CURRENT_USER'..."
smbpasswd -a "$CURRENT_USER"

# Restart Samba service and Enable it to start on boot
echo "Restarting Samba service..."
sudo systemctl restart smbd
echo "Enabling Samba to start on boot..."
sudo systemctl enable smbd
### if these fail, capture that failure and tell the user that this might indicate
### that /etc/samba/smb.conf is incorrect and then run testparm and exit.
### and cat the output from sudo journalctl -xeu smbd.service, can we cat it or is it always in less?

# Check if ufw is active before attempting to open Samba ports
if systemctl is-active --quiet ufw; then
    echo "Checking and opening Samba ports in the firewall (ufw is active)..."
    if ! ufw status | grep -q "Samba"; then
        ufw allow samba
    else
        echo "Samba ports are already open in the firewall."
    fi
else
    echo "ufw is not active, skipping firewall configuration."
fi

# Provide user instructions
echo "Samba shares have been configured."
echo "You can access them from Windows using '\\\\<your-debian-ip>\\<share-name>'."
echo "Make sure you use the username '$CURRENT_USER' and the Samba password you set."

exit 0

