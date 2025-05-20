#!/bin/bash

# Check if a block device is provided as an argument.
if [ -z "$1" ]; then
  echo "Usage: $0 /dev/sdX"
  exit 1
fi

block_device="$1"

# Check if the block device exists.
if [ ! -b "$block_device" ]; then
  echo "Error: Block device '$block_device' not found."
  exit 1
fi


# Find mounts associated with the block device.
echo "Mounts associated with $block_device:"
mount | grep "$block_device" | awk '{print $3}'


# Find Samba shares (this requires `smbstatus`).  Error handling is crucial here.
echo ""
echo "Samba shares (if any):"
if sudo smbstatus --version >/dev/null 2>&1; then
  sudo smbstatus | awk '/Share name/{print $3}'
else
  echo "Error: smbstatus command not found.  Install Samba to check for shares."
fi


# Find NFS shares (this requires parsing `/etc/exports`).  This is less precise.

echo ""
echo "NFS shares (if any - this may be incomplete):"
grep -l "$block_device" /etc/exports || true  #Quietly handles if the block device is not found in /etc/exports.

# improved check for NFS exports that are directly related to the given block device path
# requires the output of `df -h` to locate mount points and then cross check with /etc/exports
echo ""
echo "NFS exports (more precise check, requires df -h):"
mountpoint=$(df -h | grep "$block_device" | awk '{print $6}')
if [[ ! -z "$mountpoint" ]]; then
  grep -l "$mountpoint" /etc/exports
else
  echo "No mount point found for $block_device."
fi
