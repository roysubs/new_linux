#!/bin/bash

# borg list ~/.borgbackup/repo
# borg info ~/.borgbackup/repo::my_backup-2024-12-28-12-33
# borg diff ~/.borgbackup/repo::my_backup-2024-12-28-12-33 my_backup-2024-12-29-12-00
# borg extract ~/.borgbackup/repo::XXX --target ~/tmp-restore
# borg extract ~/.borgbackup/repo::XXX new_linux --target ~/tmp-restore
# borg extract ~/.borgbackup/repo::XXX new_linux/new* --target ~/tmp-restore

# Install BorgBackup
echo "Installing BorgBackup..."
sudo apt update && sudo apt install -y borgbackup

# Define backup directory
BACKUP_DIR="$HOME/.borgbackup"
ARCHIVE_NAME="my_backup"
REPO="$BACKUP_DIR/repo"
LOG_FILE="$BACKUP_DIR/${ARCHIVE_NAME}.log"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Initialize Borg repository if not already initialized
if [ ! -d "$REPO" ]; then
    echo "Initializing Borg repository..."
    borg init --encryption=none "$REPO" >> "$LOG_FILE" 2>&1
fi

# Define exclusions
EXCLUDES=(
    "$BACKUP_DIR"
    "$HOME/.cache"
    "$HOME/.mozilla"
    "$HOME/.thumbnails"
    "$HOME/.local/share/Trash"
    "$HOME/.config/google-chrome"
    "$HOME/.config/chromium"
    "$HOME/Downloads"
)

# Function to generate exclusions string
generate_excludes() {
    local excludes_str=""
    for excl in "${EXCLUDES[@]}"; do
        excludes_str+="--exclude $excl "
    done
    echo $excludes_str
}

# Function to log actions
log_action() {
    local action=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') $action" >> "$LOG_FILE"
}

# Function to create full backup
create_full_backup() {
    log_action "Starting full backup"
    START_TIME=$(date +%s)
    borg create --stats --compression lzma "$REPO::$ARCHIVE_NAME-$(date +%Y-%m-%d-%H-%M)" ~ $(generate_excludes) >> "$LOG_FILE" 2>&1
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    log_action "Full backup completed in $DURATION seconds"
}

# Function to create incremental backup
create_incremental_backup() {
    log_action "Starting incremental backup"
    START_TIME=$(date +%s)
    borg create --stats --compression lzma "$REPO::$ARCHIVE_NAME-$(date +%Y-%m-%d-%H-%M)" ~ $(generate_excludes) >> "$LOG_FILE" 2>&1
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    LAST_ARCHIVE=$(borg list "$REPO" --last 1 --format="{archive:<NAME>}\n" | tail -n1)

    # Check if any changes were backed up
    if [ $(borg diff "$REPO::$LAST_ARCHIVE" | wc -l) -eq 0 ]; then
        log_action "No changes detected, deleting the last incremental backup: $LAST_ARCHIVE"
        borg delete "$REPO::$LAST_ARCHIVE" >> "$LOG_FILE" 2>&1
    else
        log_action "Incremental backup completed in $DURATION seconds, Archive: $LAST_ARCHIVE"
        borg diff "$REPO::$(echo $LAST_ARCHIVE)" > "$BACKUP_DIR/${LAST_ARCHIVE}.changes"
    fi
}

# Determine if a full or incremental backup is needed
if [ $(borg list "$REPO" | wc -l) -eq 0 ]; then
    create_full_backup
else
    create_incremental_backup
fi

# Add cron job to run the script every hour
(crontab -l 2>/dev/null; echo "0 * * * * /bin/bash -c '$(declare -f generate_excludes log_action create_full_backup create_incremental_backup); ~/path/to/this_script.sh'") | crontab -

log_action "Setup complete. Backup system is ready. Incremental backups will run every hour."

