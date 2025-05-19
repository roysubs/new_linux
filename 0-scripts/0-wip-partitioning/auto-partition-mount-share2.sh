#!/bin/bash

# Author: Roy Wiseman, 2025-04

# ========== Discover, Mount, and Share Storage Utility ==========
#
# This script helps discover storage devices, run health checks,
# mount unmounted formatted partitions, and configure Samba shares
# for mounted filesystems.
#
# IT DOES NOT CREATE OR FORMAT PARTITIONS. It works with existing ones.
#
# Script Workflow:
# 1.  Elevate to root privileges if necessary.
# 2.  Display this plan and current storage overview.
# 3.  Perform SMART health checks on physical disks.
# 4.  Identify unmounted, formatted partitions suitable for mounting.
# 5.  Identify already mounted filesystems that could be shared.
# 6.  Ask for user confirmation to proceed with interactive actions.
# 7.  If confirmed:
#     a. Ensure necessary packages (samba, smartmontools) are installed.
#     b. Backup existing Samba configuration.
#     c. Interactively offer to mount unmounted partitions and add them to /etc/fstab.
#     d. Interactively offer to create Samba shares for:
#        - Newly mounted partitions.
#        - Already mounted partitions/filesystems not yet shared.
#        - Predefined important paths (/, /root, user's home).
#     e. Finalize Samba setup (user password, services, firewall).
#
# =================================================================

# Get the original user who invoked sudo, or current user if not via sudo
get_effective_user() {
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    else
        whoami
    fi
}

# Elevate privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[33mRoot privileges are required for most operations. Attempting to re-run with sudo...\033[0m"
    exec sudo -E "$0" "$@" # -E to preserve environment for SUDO_USER if needed
    exit $? # Should not be reached if exec succeeds
fi
EFFECTIVE_USER=$(get_effective_user)
echo "Running as user: $(whoami), Effective original user: $EFFECTIVE_USER (for share configurations)"

# --- Configuration ---
BASE_MOUNT_DIR="/mnt"
SMARTCTL_COMMAND="smartctl" # Will be sudo'ed later
SAMBA_PACKAGES=("samba" "samba-common-bin") # smbclient often in samba-common-bin or cifs-utils
SMART_TOOLS_PACKAGE="smartmontools"

# --- Helper Functions ---
run_command() {
    # Using direct execution "$@" for safety
    echo -e "\033[34mRunning: $*\033[0m"
    "$@"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "\033[31mERROR: Command failed with exit code $exit_code: $*\033[0m"
        # Decide if all failures should be fatal. Some checks might be okay to fail.
        # For now, making it fatal for key operations.
        exit $exit_code
    fi
    return $exit_code
}

# Function to check and install missing packages
ensure_packages_installed() {
    local missing_packages=()
    for pkg in "$@"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
            missing_packages+=("$pkg")
        fi
    done

    if [ ${#missing_packages[@]} -gt 0 ]; then
        echo -e "\033[33mThe following packages are required: ${missing_packages[*]}.\033[0m"
        read -r -p "Do you want to install them now? (y/N): " install_confirm
        if [[ "$install_confirm" =~ ^[Yy]$ ]]; then
            echo "Updating package list (sudo apt update)..."
            sudo apt update -y || echo -e "\033[31mapt update failed, package installation might fail.\033[0m"
            echo "Installing missing packages: ${missing_packages[*]} (sudo apt install -y ...)"
            for pkg_to_install in "${missing_packages[@]}"; do
                 sudo apt install -y "$pkg_to_install"
                 if ! dpkg-query -W -f='${Status}' "$pkg_to_install" 2>/dev/null | grep -q "ok installed"; then
                      echo -e "\033[31mERROR: Failed to install package '$pkg_to_install'. Please install it manually and re-run.\033[0m"
                      exit 1
                 fi
            done
            echo "Required packages installed."
        else
            echo -e "\033[31mRequired packages not installed. Exiting.\033[0m"
            exit 1
        fi
    fi
}

# --- Display Functions ---
display_script_plan() {
    echo -e "\033[1;36m=== Discover, Mount, and Share Storage Utility ===\033[0m"
    echo "This script will guide you through the following steps:"
    echo " 1. Display current storage layout (lsblk)."
    echo " 2. Perform SMART health checks on physical disk devices."
    echo " 3. Identify existing formatted partitions that are currently unmounted."
    echo " 4. Identify already mounted filesystems."
    echo " 5. After your confirmation, the script will offer to:"
    echo "    a. Install necessary tools (samba, smartmontools) if missing."
    echo "    b. Backup your current Samba configuration (/etc/samba/smb.conf)."
    echo "    c. Interactively mount unmounted partitions (and add to /etc/fstab)."
    echo "    d. Interactively create Samba shares for selected mount points."
    echo "    e. Finalize Samba setup (user password, services, firewall)."
    echo -e "\033[1;33mNO PARTITIONS WILL BE CREATED OR FORMATTED by this script.\033[0m"
    echo -e "It only works with existing, already formatted partitions/filesystems.\n"
}

display_current_storage() {
    echo -e "\033[1;34m--- Current Storage Layout (lsblk) ---\033[0m"
    lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT,LABEL,UUID,MODEL
    echo ""
}

# --- SMART Test Function ---
perform_smart_tests() {
    echo -e "\033[1;34m--- Performing SMART Health Checks ---\033[0m"
    ensure_packages_installed "$SMART_TOOLS_PACKAGE"

    local disk_devices
    disk_devices=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}')

    if [ -z "$disk_devices" ]; then
        echo "No disk devices found for SMART tests."
        return
    fi

    echo "Checking SMART health for physical disks..."
    for disk in $disk_devices; do
        echo -n "Device $disk: "
        if sudo "$SMARTCTL_COMMAND" -H "$disk" >/dev/null 2>&1; then
            local health_status
            health_status=$(sudo "$SMARTCTL_COMMAND" -H "$disk" | grep -iE '^(SMART overall-health self-assessment test result|self-assessment test result|SMART Health Status)' | awk -F': ' '{print $2}' | sed 's/\s*$//')
            if [[ "$health_status" =~ PASSED|OK ]]; then
                echo -e "\033[32m${health_status:-PASSED}\033[0m"
            elif [[ "$health_status" =~ FAILED|FAILING_NOW|UNKNOWN ]]; then
                echo -e "\033[31m${health_status:-FAILED/UNKNOWN}\033[0m"
                 sudo "$SMARTCTL_COMMAND" -A "$disk" # Show attributes on failure
            else
                echo -e "\033[33mStatus inconclusive: ${health_status:-N/A}\033[0m"
            fi
        else
            echo -e "\033[33mSMART data not accessible or device does not support SMART.\033[0m"
        fi
    done
    echo ""
}

# --- Device Discovery ---
identify_devices() {
    # Output format: DEVICE_PATH TYPE FSTYPE SIZE MOUNTPOINT UUID
    # We are interested in TYPE="part" with an FSTYPE, and either mounted or not.
    # Exclude swap, rom, loop.
    lsblk -rnb -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINT,UUID | awk \
        '$2 == "part" && $3 != "" && $3 != "swap" {printf "/dev/%s %s %s %s \"%s\" %s\n", $1, $2, $3, $4, $5, $6}'
}

# --- Main Script Logic ---

# Step 1: Display Plan and Initial Info (Non-interactive part)
display_script_plan
display_current_storage # Show storage before any sudo elevation for other commands

# Step 3: SMART tests (can run now as we have sudo)
perform_smart_tests

# Step 4 & 5: Identify mountable and shareable devices
echo -e "\033[1;34m--- Identifying Potential Devices for Mounting/Sharing ---\033[0m"
mapfile -t devices_info < <(identify_devices)
unmounted_partitions=()
mounted_filesystems=() # To store mount points of already mounted partitions

if [ ${#devices_info[@]} -eq 0 ]; then
    echo "No suitable partitions found to mount or share."
else
    for line in "${devices_info[@]}"; do
        # line format: /dev/sda1 part ext4 100G "" UUID_HERE
        # line format: /dev/sdb1 part ntfs 200G "/mnt/win" UUID_THERE
        read -r dev_path dev_type fs_type size mount_point_quoted uuid <<< "$line"
        mount_point=$(eval echo "$mount_point_quoted") # Safely unquote

        if [ -z "$mount_point" ]; then
            echo -e "Unmounted Partition: \033[32m$dev_path\033[0m (Type: $fs_type, Size: $size, UUID: $uuid)"
            unmounted_partitions+=("$dev_path;$fs_type;$uuid;$size") # Store relevant info
        else
            echo -e "Already Mounted: \033[32m$dev_path\033[0m at \033[34m$mount_point\033[0m (Type: $fs_type, Size: $size, UUID: $uuid)"
            mounted_filesystems+=("$mount_point;$dev_path") # Store mount_point and device
        fi
    done
fi
echo ""

# Step 6: User Confirmation to Proceed
if [ ${#unmounted_partitions[@]} -eq 0 ] && [ ${#mounted_filesystems[@]} -eq 0 ]; then
    echo "No actions available for mounting or sharing based on discovered partitions."
    # Still offer to configure predefined shares and finalize Samba if tools are installed
    read -r -p "Do you want to check/configure predefined Samba shares (/, /root, /home/$EFFECTIVE_USER) and finalize Samba setup? (y/N): " main_confirm
else
    read -r -p "Do you want to proceed with interactive mounting and sharing operations? (y/N): " main_confirm
fi

if [[ ! "$main_confirm" =~ ^[Yy]$ ]]; then
    echo "User chose not to proceed. Exiting."
    exit 0
fi

# Step 7: Action Phase
echo -e "\n\033[1;33m--- Starting Action Phase ---\033[0m"

# 7a: Ensure Samba packages
ensure_packages_installed "${SAMBA_PACKAGES[@]}"

# 7b: Backup Samba config
SMB_CONF="/etc/samba/smb.conf"
SMB_BACKUP_FILE="/etc/samba/smb.conf-$(date +%Y%m%d-%H%M%S).bak"
if [ -f "$SMB_CONF" ]; then
    echo "Backing up existing Samba configuration '$SMB_CONF' to '$SMB_BACKUP_FILE'..."
    sudo cp "$SMB_CONF" "$SMB_BACKUP_FILE"
    echo "Backup complete."
else
    echo -e "\033[33mSamba configuration file '$SMB_CONF' not found. A new one may be created.\033[0m"
fi


# --- Samba Share Creation Function ---
create_samba_share() {
    local target_path="$1" # This is the filesystem path to be shared
    local associated_device="${2:-}" # Optional: original device path for context
    local share_name_suggestion
    local actual_share_name

    # Suggest a share name
    if [ "$target_path" == "/" ]; then share_name_suggestion="rootfs";
    elif [ "$target_path" == "/root" ]; then share_name_suggestion="admin_root";
    elif [[ "$target_path" == "/home/$EFFECTIVE_USER" ]]; then share_name_suggestion="home_${EFFECTIVE_USER}";
    else share_name_suggestion=$(basename "$target_path" | sed 's/[^a-zA-Z0-9_-]//g'); fi
    [ -z "$share_name_suggestion" ] && share_name_suggestion="shared_item"

    echo -e "\n--- Configuring Samba Share for: \033[1;32m$target_path\033[0m ---"
    read -r -p "Enter Samba share name [default: $share_name_suggestion]: " actual_share_name
    actual_share_name=${actual_share_name:-$share_name_suggestion}

    # Check if share name or path already exists
    local escaped_target_path=$(echo "$target_path" | sed 's/[].[*^$(){}?+|/\\]/\\&/g')
    if grep -qE "(^\[$actual_share_name\]|^\s*path\s*=\s*$escaped_target_path\s*$)" "$SMB_CONF" 2>/dev/null; then
        echo -e "\033[33mSamba share named '$actual_share_name' or for path '$target_path' already exists. Skipping.\033[0m"
        return 0
    fi

    read -r -p "Create Samba share '$actual_share_name' for path '$target_path'? (y/N): " create_confirm
    if [[ ! "$create_confirm" =~ ^[Yy]$ ]]; then
        echo "Skipping Samba share for '$target_path'."
        return 0
    fi

    # Determine guest ok status (more restrictive for system paths)
    local guest_access="yes"
    if [[ "$target_path" == "/" || "$target_path" == "/root" ]]; then
        guest_access="no"
    fi
    
    echo "Adding share '$actual_share_name' to $SMB_CONF..."
    # Use sudo tee to append
    # Ensure path exists and has reasonable permissions (user should manage this, but we can warn)
    if [ ! -d "$target_path" ]; then
        echo -e "\033[33mWarning: Path '$target_path' does not exist. Share may not work until created.\033[0m"
    fi

    local samba_share_block
    samba_share_block="\n[$actual_share_name]\n"
    samba_share_block+="   path = $target_path\n"
    samba_share_block+="   browseable = yes\n"
    samba_share_block+="   writable = yes\n"
    samba_share_block+="   guest ok = $guest_access\n"
    samba_share_block+="   read only = no\n"
    samba_share_block+="   create mask = 0664\n" # More restrictive files
    samba_share_block+="   directory mask = 0775\n" # More restrictive directories
    samba_share_block+="   valid users = $EFFECTIVE_USER\n" # Default to the effective user
    samba_share_block+="   comment = Shared path $target_path (managed by script)\n"

    if echo -e "$samba_share_block" | sudo tee -a "$SMB_CONF" > /dev/null; then
        echo "Share '$actual_share_name' added to $SMB_CONF."
    else
        echo -e "\033[31mERROR: Failed to write share '$actual_share_name' to $SMB_CONF.\033[0m"
    fi
}


# 7c: Process unmounted partitions
if [ ${#unmounted_partitions[@]} -gt 0 ]; then
    echo -e "\n\033[1;34m--- Processing Unmounted Partitions ---\033[0m"
    for item in "${unmounted_partitions[@]}"; do
        IFS=';' read -r dev_path fs_type uuid size <<< "$item"
        echo -e "\nFound unmounted partition: \033[1;32m$dev_path\033[0m (Type: $fs_type, Size: $size, UUID: $uuid)"
        read -r -p "Do you want to mount this partition? (y/N): " mount_q
        if [[ "$mount_q" =~ ^[Yy]$ ]]; then
            default_mount_point="${BASE_MOUNT_DIR}/$(basename "$dev_path")"
            read -r -p "Enter mount point [default: $default_mount_point]: " user_mount_point
            final_mount_point=${user_mount_point:-$default_mount_point}

            if [ ! -d "$final_mount_point" ]; then
                echo "Creating directory '$final_mount_point'..."
                sudo mkdir -p "$final_mount_point" || { echo -e "\033[31mFailed to create mount point. Skipping.\033[0m"; continue; }
            fi

            echo "Mounting '$dev_path' (UUID=$uuid) to '$final_mount_point'..."
            if sudo mount UUID="$uuid" "$final_mount_point"; then
                echo "Successfully mounted."
                read -r -p "Add to /etc/fstab for persistent mount? (y/N): " fstab_q
                if [[ "$fstab_q" =~ ^[Yy]$ ]]; then
                    fstab_entry="UUID=$uuid $final_mount_point $fs_type defaults,nofail 0 2"
                    if grep -q -E "(UUID=$uuid| $final_mount_point )" /etc/fstab; then
                        echo -e "\033[33mEntry for UUID $uuid or mount point $final_mount_point already in /etc/fstab. Skipping.\033[0m"
                    else
                        echo "Adding to /etc/fstab: $fstab_entry"
                        if echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null; then
                             echo "Added to /etc/fstab."
                             sudo systemctl daemon-reexec
                        else
                             echo -e "\033[31mFailed to add to /etc/fstab.\033[0m"
                        fi
                    fi
                fi
                create_samba_share "$final_mount_point" "$dev_path"
            else
                echo -e "\033[31mMounting failed for '$dev_path'.\033[0m"
            fi
        fi
    done
fi

# 7d: Process already mounted filesystems for sharing
if [ ${#mounted_filesystems[@]} -gt 0 ]; then
    echo -e "\n\033[1;34m--- Processing Already Mounted Filesystems for Samba Sharing ---\033[0m"
    for item in "${mounted_filesystems[@]}"; do
        IFS=';' read -r mount_point dev_path <<< "$item"
        echo -e "\nFound mounted filesystem: \033[1;32m$dev_path\033[0m at \033[1;34m$mount_point\033[0m"
        create_samba_share "$mount_point" "$dev_path" # Will check internally if share exists
    done
fi

# 7d (continued): Setup predefined shares
echo -e "\n\033[1;34m--- Setting up Predefined Samba Shares (if not existing) ---\033[0m"
create_samba_share "/"
create_samba_share "/root"
if [ -d "/home/$EFFECTIVE_USER" ]; then
    create_samba_share "/home/$EFFECTIVE_USER"
else
    echo -e "\033[33mHome directory /home/$EFFECTIVE_USER not found, skipping its predefined share.\033[0m"
fi

# 7e: Finalize Samba
echo -e "\n\033[1;34m--- Finalizing Samba Configuration ---\033[0m"
echo "Checking Samba configuration with 'testparm -s'..."
if sudo testparm -s; then
    echo "Samba configuration appears valid."
    read -r -p "Set Samba password for user '$EFFECTIVE_USER' now (sudo smbpasswd -a $EFFECTIVE_USER)? (y/N): " smbpasswd_q
    if [[ "$smbpasswd_q" =~ ^[Yy]$ ]]; then
        sudo smbpasswd -a "$EFFECTIVE_USER"
    else
        echo "Skipping smbpasswd. You may need to set it manually for user '$EFFECTIVE_USER'."
    fi

    echo "Restarting Samba services (smbd and nmbd)..."
    sudo systemctl restart smbd nmbd
    echo "Ensuring Samba services are enabled to start on boot..."
    sudo systemctl enable smbd nmbd

    if command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
        echo "UFW firewall is active. Attempting to allow Samba..."
        sudo ufw allow samba
        echo "Samba firewall rule applied (if UFW is managing the firewall)."
    else
        echo "UFW is not active or not found. Skipping UFW configuration for Samba."
    fi
    echo "Samba setup finalized."
else
    echo -e "\033[31mSamba configuration (testparm -s) reported errors. Please review $SMB_CONF.\033[0m"
    echo -e "\033[31mSamba services were NOT restarted due to configuration errors.\033[0m"
fi


echo -e "\n\033[1;36m=== Script Operations Complete ===\033[0m"
echo "Final storage status:"
display_current_storage
echo "Please review all changes and test Samba share access."

exit 0
