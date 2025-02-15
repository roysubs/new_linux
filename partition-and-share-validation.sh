#!/bin/bash

# Function to check if a UUID exists in the system
check_uuid() {
    local uuid=$1
    blkid | grep -qw "$uuid"
}

# Function to check if a mount point exists
check_mountpoint() {
    local mountpoint=$1
    [ -d "$mountpoint" ]
}

# Function to check if a directory is a mounted partition
is_mounted() {
    local mountpoint=$1
    mount | awk '{print $3}' | grep -qx "$mountpoint"
}

# Function to check for unformatted partitions
check_unformatted_partitions() {
    lsblk -nr | awk '$2 == "" {print $1}'
}

# Function to check for unaligned partitions
check_unaligned_partitions() {
    if ! parted -m -s /dev/sda unit s print &>/dev/null; then
        echo "[ERROR] Cannot access /dev/sda (Permission denied). Try running with sudo."
        return
    fi
    parted -m -s /dev/sd* unit s print | awk -F: '/^[0-9]+/ && $2 !~ /^([0-9]+k|[0-9]+m|[0-9]+g|[0-9]+t)$/ {print $0}'
}

# Function to validate Samba shares
check_samba_shares() {
    if ! command -v testparm &>/dev/null; then
        echo "[SKIPPED] Samba is not installed."
        return
    fi

    # Extract share names from smb.conf
    local shares
    shares=$(grep -oP '^\[\K[^\]]+' /etc/samba/smb.conf)

    if [[ -z $shares ]]; then
        echo "[INFO] No Samba shares found."
        return
    fi

    echo "[INFO] Found Samba shares: $shares"
    
    local invalid_shares=()
    while IFS= read -r share_path; do
        if [ -n "$share_path" ] && ! check_mountpoint "$share_path"; then
            invalid_shares+=("$share_path")
        fi
    done < <(testparm -s --parameter-name="path" 2>/dev/null)

    if (( ${#invalid_shares[@]} )); then
        echo "[WARNING] Invalid Samba shares (not mounted):"
        printf '%s\n' "${invalid_shares[@]}"
    else
        echo "[OK] All Samba shares are valid."
    fi
}

# Function to validate NFS shares
check_nfs_shares() {
    if ! command -v showmount &>/dev/null; then
        echo "[SKIPPED] NFS is not installed."
        return
    fi

    local invalid_nfs_shares=()
    while IFS= read -r nfs_path; do
        if [ -n "$nfs_path" ] && ! check_mountpoint "$nfs_path"; then
            invalid_nfs_shares+=("$nfs_path")
        fi
    done < <(showmount -e localhost | tail -n +2 | awk '{print $1}')

    if (( ${#invalid_nfs_shares[@]} )); then
        echo "[WARNING] Invalid NFS shares (not mounted):"
        printf '%s\n' "${invalid_nfs_shares[@]}"
    else
        echo "[OK] All NFS shares are valid."
    fi
}

# Start of script
echo "=== Partition Validation ==="

# Step 1: Validate /etc/fstab entries
echo "------------------------------"
echo "Checking /etc/fstab entries..."
fstab_file="/etc/fstab"
while IFS= read -r line; do
    if [[ $line =~ ^# || -z $line ]]; then
        continue
    fi

    fs=$(echo "$line" | awk '{print $1}')
    mountpoint=$(echo "$line" | awk '{print $2}')

    if [[ $fs == "UUID="* ]]; then
        uuid=${fs#UUID=}
        if ! check_uuid "$uuid"; then
            echo "[ORPHANED] UUID entry: $line"
        fi
    elif [[ $fs == "/swapfile" || $mountpoint == "/" || $mountpoint == "/boot/efi" ]]; then
        echo "[SKIPPED] System-critical entry: $mountpoint"
    else
        if is_mounted "$mountpoint"; then
            echo "[OK] Mounted: $mountpoint"
        elif check_mountpoint "$mountpoint"; then
            echo "[NOT MOUNTED] $mountpoint (Exists, but not a mount)"
        else
            echo "[WARNING] Orphaned mountpoint: $mountpoint (Does not exist)"
        fi
    fi
done < "$fstab_file"

# Step 2: Check for unformatted partitions
echo "------------------------------"
echo "Checking for unformatted partitions..."
unformatted_partitions=$(check_unformatted_partitions)
if [[ -n $unformatted_partitions ]]; then
    echo "[WARNING] Unformatted partitions found:"
    echo "$unformatted_partitions"
else
    echo "[OK] No unformatted partitions found."
fi

# Step 3: Check for unaligned partitions
echo "------------------------------"
echo "Checking for unaligned partitions..."
unaligned_partitions=$(check_unaligned_partitions)
if [[ -n $unaligned_partitions ]]; then
    echo "[WARNING] Unaligned partitions found:"
    echo "$unaligned_partitions"
else
    echo "[OK] No unaligned partitions found."
fi

# Step 4: Validate Samba shares
echo "------------------------------"
echo "Checking Samba shares..."
check_samba_shares

# Step 5: Validate NFS shares
echo "------------------------------"
echo "Checking NFS shares..."
check_nfs_shares

echo "------------------------------"
echo "=== Partition validation complete. ==="

