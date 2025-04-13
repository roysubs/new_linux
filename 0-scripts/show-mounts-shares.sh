#!/bin/bash

# Checks if running as root or with sudo (exit 1 if not):
# if [ "$(id -u)" -ne 0 ]; then echo "This script must be run as root or with sudo" 1>&2; exit 1; fi
# Auto-elevates the script as sudo and reruns:
if [ "$(id -u)" -ne 0 ]; then echo "Elevation required; rerunning as sudo..."; sudo "$0" "$@"; exit 0; fi

# Check if at least 2 days have passed since the last apt update (to avoid constant updates)
if [ $(find /var/cache/apt/pkgcache.bin -mtime +2 -print) ]; then sudo apt update; fi

# Install tools if not already installed
PACKAGES=("samba" "smbclient" "nfs-kernel-server" "nfs-common" "duf")
install-if-missing() { if ! dpkg-query -W "$1" > /dev/null 2>&1; then sudo apt install -y $1; fi; }
for package in "${PACKAGES[@]}"; do install-if-missing $package; done

# Function to list all disks and their status
list_disks() {
    echo
    echo "=== Disk Inventory ==="
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE | grep -E "disk|part|lvm"
    echo
}

# Function to list active mount points
list_mounts() {
    echo
    echo "=== Active Mount Points ==="
    mount | grep -E "^/dev" || echo "No mounted filesystems."
    echo
}

# Function to list Samba shares
list_samba_shares() {
    echo
    echo "=== Samba Shares ==="
    if command -v smbclient >/dev/null 2>&1; then
        smbclient -L localhost -N | grep -E "Disk|Printer" || echo "No Samba shares found."
    else
        echo -e "\nsmbclient not installed. Install it to view Samba shares."
    fi
    echo
}

# Function to list NFS shares
list_nfs_shares() {
    echo
    echo "=== NFS Shares ==="
    if command -v sudo exportfs >/dev/null 2>&1; then
        sudo exportfs -v || echo "No NFS shares found."
    fi
    echo
    # showmount -e
}

# Function to list active CIFS connections
list_cifs_connections() {
    echo
    echo -n "=== Active CIFS Connections ==="   # -n as smbstatus introduces a linefeed
    if command -v smbstatus >/dev/null 2>&1; then
        sudo smbstatus -S || echo "No active CIFS connections found."
    else
        echo -e "\nsmbstatus not installed. Install Samba utilities to view CIFS connections."
    fi
    echo
}

# Function to list all remote mounts (e.g., CIFS and NFS)
list_remote_mounts() {
    echo
    echo "=== Active Remote Mounts ==="
    mount | grep -E "type (cifs|nfs)" || echo "No remote mounts found."
    echo
}

# Function to summarize everything
list_inventory() {
    echo
    duf
    list_disks
    list_mounts
    list_remote_mounts
    list_cifs_connections
    list_samba_shares
    list_nfs_shares
    echo
}

# Run the inventory function
list_inventory

