#!/bin/bash

# Require root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo "$0" "$@"
fi

# set -e: Causes the script to exit immediately if any command returns a non-zero exit status (an error). This prevents errors from being ignored and ensures failures are caught early.
# set -u: Treats unset variables as an error and exits immediately. This helps catch typos and missing variables that could lead to unexpected behavior.
# set -o pipefail: Ensures that a pipeline (a sequence of commands connected with |) fails if any command in the pipeline fails, not just the last one. By default, only the last command’s exit status is considered, which can mask earlier failures.
set -euo pipefail

# Function to check if a device is already in fstab
is_in_fstab() {
    grep -q "^UUID=$1" /etc/fstab
}

# Identify large (>10GB) formatted partitions, excluding SWAP and special devices
devices=( $(lsblk -bnplo NAME,SIZE,TYPE,FSTYPE | awk '$2 >= 10737418240 && $3 == "part" && $4 != "swap" {print $1}') )

echo $devices

if [[ ${#devices[@]} -eq 0 ]]; then
    echo "No suitable devices found."
    exit 1
fi

# Mount devices and update fstab
nfs_index=1
for dev in "${devices[@]}"; do
    uuid=$(blkid -s UUID -o value "$dev")
    fstype=$(lsblk -nplo FSTYPE "$dev" | head -n 1)
    mount_point="/mnt/$(basename "$dev")"
    nfs_mount="/mnt/nfs/nas$nfs_index"

    mkdir -p "$mount_point" "$nfs_mount"

    # Mount if not already mounted and ensure fstab entry exists
    if ! mountpoint -q "$mount_point"; then
        if ! is_in_fstab "$uuid"; then
            echo "UUID=$uuid  $mount_point  $fstype  defaults,nofail  0  2" | tee -a /etc/fstab
        fi
        mount UUID="$uuid" "$mount_point"
    fi
    
    # NFS bind mount
    if ! mountpoint -q "$nfs_mount"; then
        if ! grep -q "^$mount_point " /etc/fstab; then
            echo "$mount_point  $nfs_mount  none  bind,nofail  0  0" | tee -a /etc/fstab
        fi
        mount --bind "$mount_point" "$nfs_mount"
    fi

    ((nfs_index++))
done

# Output useful NFS-related commands
cat <<EOF

Useful NFS-related commands:
1. Show mounted NFS shares:          cat /proc/mounts | grep nfs
2. Check active NFS services:        systemctl status nfs-server
3. Restart NFS server:               systemctl restart nfs-server
4. Stop NFS server:                  systemctl stop nfs-server
5. Start NFS server:                 systemctl start nfs-server
6. Check NFS exports:                exportfs -v
7. Unmount an NFS share:             umount /mnt/nfs/nasX  (Replace X with the index)
8. Remove NFS mounts from fstab:     sed -i '/\/mnt\/nfs\/nas/d' /etc/fstab
9. List available NFS shares:        showmount -e localhost
10. Show NFS clients:                netstat -an | grep :2049
EOF
