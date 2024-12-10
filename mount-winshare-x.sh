#!/bin/bash

# Variables
SHARE="//white/d"
MOUNT_POINT="/mnt/white_d"
USER_MOUNT_POINT="$HOME/white_d"
INSTALL_CMD=""

# Determine package manager
if command -v apt >/dev/null 2>&1; then
    INSTALL_CMD="sudo apt install -y cifs-utils"
elif command -v yum >/dev/null 2>&1; then
    INSTALL_CMD="sudo yum install -y cifs-utils"
elif command -v pacman >/dev/null 2>&1; then
    INSTALL_CMD="sudo pacman -S --noconfirm cifs-utils"
else
    echo "Unsupported package manager. Please install 'cifs-utils' manually."
    exit 1
fi

# Install necessary components
echo "Installing necessary components..."
$INSTALL_CMD

# Prompt user for mount method
read -p "Mount globally under $MOUNT_POINT (requires sudo) or locally under $USER_MOUNT_POINT? [g/l]: " choice

if [[ "$choice" =~ ^[Gg]$ ]]; then
    TARGET="$MOUNT_POINT"
    sudo mkdir -p "$TARGET"
    echo "Mounting under $MOUNT_POINT..."
elif [[ "$choice" =~ ^[Ll]$ ]]; then
    TARGET="$USER_MOUNT_POINT"
    mkdir -p "$TARGET"
    echo "Mounting under $USER_MOUNT_POINT..."
else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Prompt for credentials
read -p "Enter username for the Samba share: " SMB_USER
read -s -p "Enter password for $SMB_USER: " SMB_PASS
echo

# Mount the share
echo "Mounting $SHARE to $TARGET..."
sudo mount -t cifs "$SHARE" "$TARGET" -o username="$SMB_USER",password="$SMB_PASS" && echo "Mount successful."

# Add to /etc/fstab for persistent mount (optional)
read -p "Add this mount to /etc/fstab for persistence? [y/n]: " persist
if [[ "$persist" =~ ^[Yy]$ ]]; then
    echo "$SHARE $TARGET cifs username=$SMB_USER,password=$SMB_PASS 0 0" | sudo tee -a /etc/fstab
    echo "Entry added to /etc/fstab."
fi

echo "Done."

