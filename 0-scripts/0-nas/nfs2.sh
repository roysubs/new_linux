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
devices=( $(lsblk -bnplo NAME,SIZE,TYPE,FSTYPE | awk '$2 >= 10737418240 && $3 == "part" && $4 != "swap" && $4 != "" {print $1}') )

# List all devices stored in the array
echo "Found devices:"   # ${devices[@]}
for device in "${devices[@]}"; do
    echo "$device"
done

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
        if ! grep -q "^UUID=$uuid" /etc/fstab; then
            # Avoid duplicate fstab entries by checking first
            echo "UUID=$uuid  $mount_point  $fstype  defaults,nofail  0  2" >> /etc/fstab
            echo "Added $uuid to /etc/fstab"  # Debugging output
        else
            echo "$uuid already in /etc/fstab, skipping..."  # Debugging output
        fi
        mount "$dev" "$mount_point" || { echo "Failed to mount $dev"; exit 1; }
    fi
    
    # NFS bind mount
    if ! mountpoint -q "$nfs_mount"; then
        if ! grep -q "^$mount_point " /etc/fstab; then
            echo "$mount_point  $nfs_mount  none  bind,nofail  0  0" >> /etc/fstab
            echo "Added bind mount for $mount_point to /etc/fstab"  # Debugging output
        else
            echo "Bind mount for $mount_point already in /etc/fstab, skipping..."  # Debugging output
        fi
        mount --bind "$mount_point" "$nfs_mount"
    fi

    ((nfs_index++))
done

# Add NFS exports for the mounts
for ((i=1; i<=nfs_index-1; i++)); do
    if ! grep -q "^/mnt/nfs/nas$i" /etc/exports; then
        echo "/mnt/nfs/nas$i *(rw,sync,no_subtree_check)" | tee -a /etc/exports
    fi
done

# Restart NFS service to apply changes
systemctl restart nfs-server

# Output useful NFS-related commands
cat <<EOF

Useful NFS-related commands:
exportfs -v                   # Check NFS exports
showmount -e localhost        # List available NFS shares
cat /proc/mounts | grep nfs   # Show mounted NFS shares
netstat -an | grep :2049      # Show NFS clients
systemctl status nfs-server   # Check active NFS services (also restart | stop | start)
umount /path/to/mount         # Unmount an NFS share
sed -i '/\/mnt\/nfs\/nas/d' /etc/fstab   # Remove an NFS mount from /etc/fstab

Troubleshooting:
The nfs-server.service should be "active (exited)" as rpc.nfsd (the NFS daemon) runs
as a kernel thread, not as a persistent user-space process. The systemd service starts
it, then exits once it's running in the background.
"(status=1/FAILURE)" would indicate that it can't start. This error comes from
"exportfs -r", which is run before starting the NFS server (ExecStartPre=/usr/sbin/exportfs -r).
This could be due to duplicate export entries in /etc/exports, or leftover export entries in
/var/lib/nfs/etab that were not cleaned up properly.

sudo vi /etc/exports   # Check for repeated/incorrect entries, remove then save and exit.
sudo exportfs -uav     # Unexport all current shares
sudo exportfs -r       # Re-read exports (i.e. read /etc/exportfs)
Force-clear old NFS exports:
   sudo rm -f /var/lib/nfs/etab
   sudo touch /var/lib/nfs/etab
   sudo exportfs -a
sudo systemctl restart nfs-server   # Restart NFS-Server
sudo systemctl status nfs-server    # Check status
# If everything is working, it should be "active (exited)" and show "SUCCESS" without errors.
EOF

