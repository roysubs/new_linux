#!/bin/bash

# Find all mounted partitions
mounted_partitions=$(lsblk -ln -o NAME,MOUNTPOINT | awk '$2 ~ /^\// {print "/dev/"$1" "$2}')

# Function to check if a partition is already in /etc/exports
check_nfs_conf() {
    local mount_point=$1
    grep -q -E "^$mount_point" /etc/exports
}

# Function to add NFS sharing options
add_nfs_share() {
    local mount_point=$1
    echo "Adding NFS share for $mount_point..."

    # NFS share configuration
    share_config="$mount_point *(rw,sync,no_subtree_check)"

    # Append to /etc/exports
    echo "$share_config" | sudo tee -a /etc/exports > /dev/null

    # Export the new share and restart NFS services
    echo "Running: sudo exportfs -ra"
    sudo exportfs -ra
    echo "Running: sudo systemctl restart nfs-server"
    sudo systemctl restart nfs-server

    echo "NFS share for $mount_point added and NFS services restarted."
}

# Display mounted partitions
echo "Mounted partitions:"
echo "$mounted_partitions"
echo

# Process each mounted partition
IFS=$'\n'
for entry in $mounted_partitions; do
    device=$(echo "$entry" | awk '{print $1}')
    mounted_part=$(echo "$entry" | awk '{print $2}')

    echo "Checking device $device mounted at $mounted_part..."

    if check_nfs_conf "$mounted_part"; then
        echo "Mount point $mounted_part already exists in NFS configuration. Skipping."
    else
        read -p "Would you like to create an NFS share for $mounted_part? (y/n): " confirm
        case $confirm in
            [Yy]*)
                add_nfs_share "$mounted_part"
                ;;
            *)
                echo "Skipping NFS share creation for $mounted_part."
                ;;
        esac
    fi

done

# Show existing NFS exports
echo
echo "Existing NFS shares:" 
sudo exportfs -v

echo
echo "NFS sharing completed."
echo "To view or modify shares, check /etc/exports."
echo "To remove a share, edit /etc/exports to delete the corresponding line, then run 'sudo exportfs -ra' to refresh exports."

