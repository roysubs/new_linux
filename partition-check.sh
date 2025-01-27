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

# Function to check for unformatted partitions
check_unformatted_partitions() {
    lsblk -nr | awk '$2 == "" {print $1}'
}

# Function to check for unaligned partitions
check_unaligned_partitions() {
    parted -m -s /dev/sd* unit s print | awk -F: '/^[0-9]+/ && $2 !~ /^([0-9]+k|[0-9]+m|[0-9]+g|[0-9]+t)$/ {print $0}'
}

# Function to validate Samba shares
check_samba_shares() {
    testparm -s --parameter-name="path" 2>/dev/null | while read -r share_path; do
        if [ -n "$share_path" ] && ! check_mountpoint "$share_path"; then
            echo "$share_path"
        fi
    done
}

# Function to validate NFS shares
check_nfs_shares() {
    if ! command -v showmount &>/dev/null; then
        echo "NFS is not installed, skipping NFS share check."
        return
    fi
    showmount -e localhost | tail -n +2 | awk '{print $1}' | while read -r nfs_path; do
        if [ -n "$nfs_path" ] && ! check_mountpoint "$nfs_path"; then
            echo "$nfs_path"
        fi
    done
}

# Start of script
clear
echo "Starting partition validation..."

# Step 1: Validate /etc/fstab entries
fstab_file="/etc/fstab"
echo "Checking /etc/fstab entries..."
while IFS= read -r line; do
    if [[ $line =~ ^# || -z $line ]]; then
        continue
    fi

    fs=$(echo "$line" | awk '{print $1}')
    mountpoint=$(echo "$line" | awk '{print $2}')
    
    if [[ $fs == "UUID="* ]]; then
        uuid=${fs#UUID=}
        if ! check_uuid "$uuid"; then
            echo "Orphaned entry found: $line"
            read -rp "Do you want to remove this entry from /etc/fstab? (yes/no): " response
            if [[ $response == "yes" ]]; then
                sed -i "\|$line|d" "$fstab_file"
                echo "Entry removed."
            fi
        fi
    elif [[ $fs == "/swapfile" || $mountpoint == "/" || $mountpoint == "/boot/efi" ]]; then
        echo "Skipping system-critical entry: $line"
    else
        echo "Validating mountpoint: $mountpoint"
        if ! check_mountpoint "$mountpoint"; then
            echo "Orphaned mountpoint found: $line"
            read -rp "Do you want to remove this entry from /etc/fstab? (yes/no): " response
            if [[ $response == "yes" ]]; then
                sed -i "\|$line|d" "$fstab_file"
                echo "Entry removed."
            fi
        fi
    fi
done < "$fstab_file"

# Step 2: Check for unformatted partitions
echo "Checking for unformatted partitions..."
unformatted_partitions=$(check_unformatted_partitions)
if [[ -n $unformatted_partitions ]]; then
    echo "Unformatted partitions found:"
    echo "$unformatted_partitions"
else
    echo "No unformatted partitions found."
fi

# Step 3: Check for unaligned partitions
echo "Checking for unaligned partitions..."
unaligned_partitions=$(check_unaligned_partitions)
if [[ -n $unaligned_partitions ]]; then
    echo "Unaligned partitions found:"
    echo "$unaligned_partitions"
else
    echo "No unaligned partitions found."
fi

# Step 4: Validate Samba shares
echo "Checking Samba shares..."
if command -v smbclient &>/dev/null; then
    invalid_samba_shares=$(check_samba_shares)
    if [[ -n $invalid_samba_shares ]]; then
        echo "Invalid Samba shares found:"
        echo "$invalid_samba_shares"
    else
        echo "All Samba shares are valid."
    fi
else
    echo "Samba is not installed, skipping Samba share check."
fi

# Step 5: Validate NFS shares
echo "Checking NFS shares..."
check_nfs_shares

echo "Partition validation complete."

