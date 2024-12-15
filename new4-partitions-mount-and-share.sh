#!/bin/bash

echo "Discover disks and filesystems then mount them under /mnt"

# Ensure we're running as root or with sudo (use second line to auto-elevate)
# if [ "$(id -u)" -ne 0 ]; then echo "This script must be run as root or with sudo" 1>&2; exit 1; fi
if [ "$(id -u)" -ne 0 ]; then echo -e "\033[31mElevation required; rerunning as sudo...\033[0m"; sudo "$0" "$@"; exit 0; fi

# Check if 2 days have passed since the last update
if [ $(find /var/cache/apt/pkgcache.bin -mtime +2 -print) ]; then sudo apt update; fi

# Install tools if not already installed
PACKAGES=("samba")   # "nfs-kernel-server" "nfs-common"
install-if-missing() { if ! dpkg-query -W "$1" > /dev/null 2>&1; then sudo apt install -y $1; fi; }
for package in "${PACKAGES[@]}"; do install-if-missing $package; done

# Backup existing smb.conf with a timestamp
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="/etc/samba/smb.conf-$TIMESTAMP.bak"
echo "Backing up existing Samba configuration to $BACKUP_FILE..."
cp /etc/samba/smb.conf "$BACKUP_FILE"
CALLING_USER=$(whoami)   # will set to who is running (root or whoever ran sudo)

# Function to display storage information
display_storage() {
    echo -e "\nDiscovering storage devices..."
    echo -e "\nDevice Information:\n"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
}

# Function to run SMART tests and display results
run_smart_tests() {
    echo -e "\nRunning SMART tests on discovered devices..."

    # Check if smartctl is installed
    if ! command -v sudo smartctl &>/dev/null; then
        echo "Installing smartctl ..."
        sudo apt install -y smartmontools
    fi

    for device in $(lsblk -dn -o NAME | grep -E '^[a-z]+$'); do
        device_path="/dev/$device"
        echo -e "\nSMART test for $device_path:"
        sudo smartctl -H "$device_path" | grep -E "(SMART overall-health|PASSED|FAILED|FAILING_NOW)"
    done
}

# Function to suggest mount points
suggest_mount_point() {
    local device=$1
    local base_mount="/mnt"
    local device_name=$(basename "$device")
    echo "$base_mount/$device_name"
}

# Function to mount an unmounted device
mount_device() {
    local device=$1
    local suggested_mount_point=$(suggest_mount_point "$device")

    echo -e "\nSuggested mount point: $suggested_mount_point"
    read -p "Enter a mount point (or press Enter to use the suggestion): " mount_point

    if [[ -z "$mount_point" ]]; then
        mount_point=$suggested_mount_point
    fi

    # Create the mount point if it doesn't exist
    if [[ ! -d "$mount_point" ]]; then
        echo "Creating mount point at $mount_point..."
        mkdir -p "$mount_point"
    fi
    echo "Mounting $device at $mount_point..."
    mount "$device" "$mount_point"
    echo "$device successfully mounted at $mount_point."

    create_samba_share "$mount_point"
}

# Function to share a non-shared mount



# Function to configure a Samba share for a given directory
create_samba_share() {
    local mount_point=$1
    local share_name=""

    # Set share names for specific paths
    case "$mount_point" in
        "/")
            share_name="root"
            ;;
        "/root")
            share_name="user-root"
            ;;
        "/home/$CALLING_USER")
            share_name="user-$CALLING_USER"
            ;;
        *)
            share_name=$(basename "$mount_point")
            ;;
    esac

    # Check if the Samba share already exists
    if grep -q "^\[$share_name\]" /etc/samba/smb.conf; then
        echo "Information: Samba share for $mount_point already exists in smb.conf. Skipping."
        return 0   # 'continue' is only meaningful in a `for', `while', or `until' loop        
    fi

    echo -e "Would you like to create a Samba share for '$mount_point'? (y/n)"
    read -r -p "Would you like to create a Samba share for '$mount_point'? (y/n): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then    # if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
        echo "Skipping Samba share creation for '$mount_point'..."
        return 0   # 'continue' is only meaningful in a `for', `while', or `until' loop
    fi

    # Add a Samba share for the directory
    echo "Configuring Samba share for $mount_point..."
    cat <<EOF >> /etc/samba/smb.conf

[$share_name]
   path = $mount_point
   valid users = $CALLING_USER
   read only = no
   browsable = yes
   guest ok = $( [[ "$mount_point" == "/" || "$mount_point" == "/root" ]] && echo "no" || echo "yes" )
   create mask = 0775
   directory mask = 0775
   comment = Shared by script
EOF
}

# Function to check and share already mounted devices
share_already_mounted_devices() {
    echo -e "\nChecking for already mounted but unshared devices..."

    # List all mounted devices with their mount points
    local mounted_devices=$(lsblk -ln -o NAME,MOUNTPOINT | awk '$2 ~ /^\// {print "/dev/"$1" "$2}')

    while read -r device mount_point; do
        if [[ -z "$device" || -z "$mount_point" ]]; then
            continue
        fi

        local share_name="$(basename "$mount_point")"

        # Handle special cases for share names
        case "$mount_point" in
            "/")
                share_name="root"
                ;;
            "/root")
                share_name="user-root"
                ;;
            "/home/$CALLING_USER")
                share_name="user-$CALLING_USER"
                ;;
        esac

        # Check if the share already exists
        echo "Checking if share for $mount_point exists..."
        echo "^\[$share_name\] /etc/samba/smb.conf"
        grep -q "^\[$share_name\]" /etc/samba/smb.conf

        if grep -q "^\[$share_name\]" /etc/samba/smb.conf; then
            echo "Samba share for $mount_point already exists. Skipping."
            continue
        fi

        echo -e "\nDevice $device is mounted at $mount_point but not shared."
        echo -e "Would you like to create XX a Samba share for '$mount_point'? (y/n)"

        read -r -p "Would you like to create YY a Sambad share for '$mount_point'? (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            create_samba_share "$mount_point"
        else
            echo "Skipping Samba share creation for '$mount_point'..."
            continue  # Instead of return 0, use continue to proceed to the next device
        fi
    done <<< "$mounted_devices"
}

# Finalize Samba configuration
samba_finalise() {
    echo "Setting up Samba for the calling user ($CALLING_USER)..."
    smbpasswd -a "$CALLING_USER"

    echo "Restarting Samba services..."
    systemctl restart smbd nmbd

    echo "Enabling Samba to start on boot..."
    systemctl enable smbd

    if systemctl is-active --quiet ufw; then
        echo "Configuring UFW to allow Samba..."
        ufw allow samba
    else
        echo "UFW is not active, skipping firewall configuration."
    fi

    echo "Samba configuration finalized successfully."
}

# Main script execution
echo

display_storage

run_smart_tests

echo -e "\nChecking for unmounted storage devices..."

# List unmounted devices, filtering out root devices, swap, ISO9660, RAID members, and small partitions
unmounted_devices=$(lsblk -ln -o NAME,SIZE,FSTYPE,MOUNTPOINT | \
    grep -v -E '^sd[a-z] [[:space:]]*' | \
    grep -v -E 'swap|iso9660|vfat' | \
    awk '$2 ~ /[0-9]+[MGT]$/ && $4 == "" {print "/dev/"$1}')

if [[ -z "$unmounted_devices" ]]; then
    echo "All devices are mounted."
else
    echo -e "\nUnmounted devices found:"
    for device in $unmounted_devices; do
        echo "- $device"
    done

    for device in $unmounted_devices; do
        read -r -p "Do you want to mount $device? (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            mount_device "$device"
        else
            echo "$device will not be mounted."
        fi
    done
fi

# Share specific directories
create_samba_share "/"
create_samba_share "/root"
create_samba_share "/home/$CALLING_USER"

# Share already mounted but unshared devices
share_already_mounted_devices

samba_finalise

echo -e "\nFinal storage status:\n"
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
echo
