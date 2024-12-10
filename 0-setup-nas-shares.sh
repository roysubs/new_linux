#!/bin/bash

# Check if running as sudo
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run with sudo or as root."
  exit 1
fi

# Minimum size in GB for a volume to be shared
MIN_VOLUME_SIZE_GB=20

# Samba configuration file
SAMBA_CONF="/etc/samba/smb.conf"

# Install Samba if not already installed
if ! command -v smbd &> /dev/null; then
    echo "Samba not found. Installing..."
    apt update && apt install -y samba
fi

# Backup the original Samba config
if [ ! -f "${SAMBA_CONF}.backup" ]; then
    cp "$SAMBA_CONF" "${SAMBA_CONF}.$(date +'%Y-%m-%d_%H-%M-%S').backup"
    echo "Backup of original Samba config saved to ${SAMBA_CONF}.$(date +'%Y-%m-%d_%H-%M-%S').backup"
fi

# Function to get the size of a volume
get_volume_size_gb() {
    df --output=size -BG "$1" | tail -n 1 | sed 's/[^0-9]//g'
}

# Detect large volumes
echo "Detecting volumes larger than ${MIN_VOLUME_SIZE_GB}GB..."
VOLUMES=$(df --output=target,size -BG | tail -n +2 | awk -v min_size=$MIN_VOLUME_SIZE_GB \
    '$2+0 >= min_size {print $1}')

if [ -z "$VOLUMES" ]; then
    echo "No volumes larger than ${MIN_VOLUME_SIZE_GB}GB detected. Exiting."
    exit 1
fi

echo "Volumes to share:"
echo "$VOLUMES"

# Configure Samba
echo "Configuring Samba..."
cat > "$SAMBA_CONF" <<EOL
[global]
   workgroup = WORKGROUP
   server string = Debian NAS
   netbios name = $(hostname)
   security = user
   map to guest = Bad User
   guest account = nobody

EOL

# Create shares for each volume
for VOL in $VOLUMES; do
    VOL_NAME=$(basename "$VOL")
    SHARE_PATH=$(realpath "$VOL")
    mkdir -p "$SHARE_PATH" 2>/dev/null
    chmod 777 "$SHARE_PATH"

    echo "Sharing $VOL as $VOL_NAME..."

    cat >> "$SAMBA_CONF" <<EOL
[$VOL_NAME]
   path = $SHARE_PATH
   browseable = yes
   read only = no
   guest ok = yes

EOL
done

# Restart Samba to apply changes
echo "Restarting Samba services..."
systemctl restart smbd nmbd

echo "Samba configuration complete. Shared volumes:"
for VOL in $VOLUMES; do
    echo " - \\$(hostname)\\$(basename "$VOL")"
done

echo "Your NAS is ready. You can access the shares from any device on your network."

