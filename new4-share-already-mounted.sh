#!/bin/bash

# [/mnt/sdb1]
#     path = /mnt/sdb1
#     browseable = yes
#     read only = no
#     guest ok = yes

# Display mounted partitions
echo "Mounted partitions:"
lsblk -ln -o NAME,MOUNTPOINT | awk '$2 ~ /^\// {print "/dev/"$1" "$2}'

# Function to check if a partition is in samba configuration
check_samba_conf() {
    local mount_point=$1
    grep -q "$mount_point" /etc/samba/smb.conf
}

# Function to add samba sharing options
add_samba_share() {
    local device=$1
    local mount_point=$2
    local share_name=$(basename "$mount_point")
    echo "Adding Samba share for $mount_point ($device)..."

    # Samba share configuration
    share_config="[$share_name]
    path = $mount_point
    valid users = nobody
    read only = no
    browsable = yes
    guest ok = yes
    create mask = 0775
    directory mask = 0775
    comment = Auto-generated Samba share"

    # Append to smb.conf
    echo "$share_config" | sudo tee -a /etc/samba/smb.conf > /dev/null

    # Restart Samba services
    sudo systemctl restart smbd
    sudo systemctl restart nmbd

    echo "Samba share for $mount_point added and Samba services restarted."
}

# Read mounted partitions into an array
mounted_partitions=($(lsblk -ln -o NAME,MOUNTPOINT | awk '$2 ~ /^\// {print "/dev/"$1":"$2}'))

# Iterate over each mounted partition
for entry in "${mounted_partitions[@]}"; do
    device="${entry%%:*}"
    mounted_part="${entry#*:}"

    echo "Checking device $device mounted at $mounted_part..."
    
    if check_samba_conf "$mounted_part"; then
        echo "Mount point $mounted_part already exists in Samba configuration. Skipping."
    else
        read -p "Would you like to create a Samba share for $mounted_part (share name: $(basename "$mounted_part"))? (y/n): " response
        if [[ "$response" == "y" ]]; then
            add_samba_share "$device" "$mounted_part"
        else
            echo "Skipping Samba share creation for $mounted_part."
        fi
    fi
done

# Show existing Samba shares and their status
echo -e "\nExisting Samba shares and their status:"
sudo smbstatus -S

