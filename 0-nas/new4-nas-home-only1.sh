#!/bin/bash

# Function to generate the next available nasX name
get_next_share_name() {
  local current_max=$(grep -oP '\[nas\d+\]' /etc/samba/smb.conf | grep -oP '\d+' | sort -n | tail -1)
  echo "nas$((current_max + 1))"
}

# List valid partitions with sizes (exclude SWAP, 0 size, and non-partitions)
lsblk -ln -o NAME,TYPE,SIZE,MOUNTPOINT | grep -E "part" | awk '$3 != "0" && $3 != "" && $2 != "SWAP" { print "/dev/" $1, $3 }' > valid_partitions.txt

# Process each valid partition
while read -r device size; do
  mount_point="/mnt/${device##*/}"
  
  # Skip if already mounted
  if grep -q "$mount_point" /etc/mtab; then
    echo "$device is already mounted at $mount_point. Skipping..."
    continue
  fi

  # Create mount point
  mkdir -p "$mount_point"
  mount "$device" "$mount_point"

  # Get the next nasX name
  share_name=$(get_next_share_name)

  # Add Samba share
  cat <<EOF >> /etc/samba/smb.conf
[$share_name]
   path = $mount_point
   valid users = boss
   read only = no
   browsable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   comment = Added by script, size: $size
EOF

  echo "Added Samba share for $device as $share_name with path $mount_point"
done < valid_partitions.txt

# Restart Samba
systemctl restart smbd

