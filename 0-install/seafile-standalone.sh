#!/bin/bash

# Variables
SEAFILE_VERSION="11.0.4"  # Change this to the latest version if needed
INSTALL_DIR="/opt/seafile"
SEAFILE_USER="seafile"
SEAFILE_PORT=8000
MYSQL_ROOT_PASS="seafile_root_password"  # Change this if using MySQL (not required for SQLite)

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Update system
echo "[*] Updating system..."
apt update && apt upgrade -y

# Install dependencies
echo "[*] Installing dependencies..."
apt install -y python3 python3-pip libmariadb-dev libevent-dev sqlite3 curl wget unzip

# Create Seafile user
echo "[*] Creating Seafile user..."
useradd -r -s /bin/bash -m -d "$INSTALL_DIR" "$SEAFILE_USER"

# Download Seafile Server
echo "[*] Downloading Seafile..."
cd /tmp
wget "https://s3.eu-central-1.amazonaws.com/download.seadrive.org/seafile-server_${SEAFILE_VERSION}_x86-64.tar.gz"

# Extract and move to install directory
echo "[*] Installing Seafile..."
mkdir -p "$INSTALL_DIR"
tar -xzf "seafile-server_${SEAFILE_VERSION}_x86-64.tar.gz" -C "$INSTALL_DIR"
rm "seafile-server_${SEAFILE_VERSION}_x86-64.tar.gz"

# Change ownership
chown -R "$SEAFILE_USER":"$SEAFILE_USER" "$INSTALL_DIR"

# Initialize Seafile with SQLite (change for MySQL)
echo "[*] Setting up Seafile with SQLite..."
sudo -u "$SEAFILE_USER" bash -c "
cd $INSTALL_DIR/seafile-server-${SEAFILE_VERSION} &&
./setup-seafile.sh auto -n 'Seafile Server' -i '127.0.0.1' -p $SEAFILE_PORT -d sqlite
"

# Create systemd service
echo "[*] Creating systemd service for Seafile..."
cat <<EOF > /etc/systemd/system/seafile.service
[Unit]
Description=Seafile Server
After=network.target

[Service]
Type=forking
User=$SEAFILE_USER
Group=$SEAFILE_USER
ExecStart=$INSTALL_DIR/seafile-server-${SEAFILE_VERSION}/seafile.sh start
ExecStop=$INSTALL_DIR/seafile-server-${SEAFILE_VERSION}/seafile.sh stop
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable --now seafile.service

echo "[*] Seafile installation complete!"
echo "Access Seafile at: http://localhost:$SEAFILE_PORT/"

