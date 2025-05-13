#!/bin/bash

BACKUP_DIR="$HOME/.backup-home"
REPO="$BACKUP_DIR/borg-repo"
SYSTEMD_SERVICE="borg-backup.service"
SYSTEMD_TIMER="borg-backup.timer"
BACKUP_SCRIPT="$BACKUP_DIR/backup.sh"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Check if Borg is installed, install if missing
if ! command -v borg &> /dev/null; then
    echo "BorgBackup not found. Installing..."
    sudo apt update && sudo apt install -y borgbackup
fi

# Initialize Borg repository (only needed once)
if [ ! -d "$REPO" ]; then
    echo "Initializing Borg repository..."
    echo "Enter a secure passphrase for encryption:"
    read -s BORG_PASSPHRASE
    export BORG_PASSPHRASE
    borg init --encryption=repokey "$REPO"
fi

# Create a new incremental backup
BACKUP_NAME=$(date +"%Y-%m-%d_%H-%M-%S")
echo "Creating backup: $BACKUP_NAME"

borg create --compression zstd "$REPO::$BACKUP_NAME" "$HOME" \
    --exclude "$HOME/.backup-home" \
    --exclude "$HOME/.cache" \
    --exclude "$HOME/.mozilla" \
    --exclude "$HOME/.local/share/Trash"

echo "Backup $BACKUP_NAME completed."

# Prune old backups (keep last 24 hourly, 7 daily, 4 weekly, 6 monthly)
borg prune --keep-hourly=24 --keep-daily=7 --keep-weekly=4 --keep-monthly=6 "$REPO"

# List available backups
echo "Available backups:"
borg list "$REPO"

# SYSTEMD SERVICE SETUP
if [ ! -f "/etc/systemd/system/$SYSTEMD_SERVICE" ]; then
    echo "Setting up systemd service..."
    sudo bash -c "cat <<EOF > /etc/systemd/system/$SYSTEMD_SERVICE
[Unit]
Description=Borg Backup Service
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=$USER
ExecStart=$BACKUP_SCRIPT
EOF
    "
    echo "Systemd service created: $SYSTEMD_SERVICE"
fi

# SYSTEMD TIMER SETUP
if [ ! -f "/etc/systemd/system/$SYSTEMD_TIMER" ]; then
    echo "Setting up systemd timer..."
    sudo bash -c "cat <<EOF > /etc/systemd/system/$SYSTEMD_TIMER
[Unit]
Description=Run Borg Backup every 30 minutes

[Timer]
OnCalendar=*:0/30
Persistent=true

[Install]
WantedBy=timers.target
EOF
    "
    echo "Systemd timer created: $SYSTEMD_TIMER"
fi

# Reload systemd and enable timer
echo "Enabling and starting systemd timer..."
sudo systemctl daemon-reload
sudo systemctl enable --now "$SYSTEMD_TIMER"

# INSTRUCTIONS FOR THE USER
echo -e "\n🚀 Borg Backup Setup Complete 🚀\n"
echo "📌 To manually trigger a backup, run:"
echo "    sudo systemctl start $SYSTEMD_SERVICE"
echo ""
echo "📌 To check the status of the backup service:"
echo "    systemctl status $SYSTEMD_SERVICE"
echo ""
echo "📌 To view logs of the last 50 backup runs:"
echo "    journalctl -u $SYSTEMD_SERVICE --no-pager --lines=50"
echo ""
echo "📌 To see scheduled backup timers:"
echo "    systemctl list-timers --all | grep $SYSTEMD_TIMER"
echo ""
echo "📌 To restore a specific file from a backup:"
echo "    borg extract \"$REPO::BACKUP_NAME\" path/to/file"
echo ""
echo "📌 To browse backups without extracting:"
echo "    borg mount \"$REPO::BACKUP_NAME\" /mnt"
echo "    (Then navigate /mnt to see your files)"
echo "    borg umount /mnt"
echo ""
echo "✅ Systemd service and timer have been set up successfully!"

