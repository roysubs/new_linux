#!/bin/bash

SAMBA_CONF="/etc/samba/smb.conf"
BACKUP_FILE="${SAMBA_CONF}.$(date +'%Y-%m-%d_%H-%M-%S').bak"

# Backup the original Samba config
cp "$SAMBA_CONF" "$BACKUP_FILE"
echo "Samba config backed up to $BACKUP_FILE"

# Function to add a Samba share
add_samba_share() {
    local share_name="$1"
    local share_path="$2"
    echo "Adding Samba share: $share_name at $share_path"
    cat <<EOL >> "$SAMBA_CONF"

[$share_name]
   path = $share_path
   browseable = yes
   read only = no
   guest ok = yes
   comment = Shared by script
EOL
}

# Detect unmounted partitions and mount them
echo "Detecting unmounted partitions and sharing them..."

lsblk --noheadings --output NAME,FSTYPE,SIZE,MOUNTPOINT | while read -r name fstype size mountpoint; do
  # Skip the root (/) and swap partitions
  if [[ "$mountpoint" == "/" || "$fstype" == "swap" ]]; then
    continue
  fi

  # If it's not mounted and has a filesystem type, mount it
  if [[ -z "$mountpoint" && -n "$fstype" ]]; then
    size_value=$(echo "$size" | grep -o -E '[0-9.]+')
    size_unit=$(echo "$size" | grep -o -E '[A-Z]+')

    # Convert size to MB for comparison
    case "$size_unit" in
      G) size_in_mb=$(echo "$size_value * 1024" | bc) ;;
      M) size_in_mb=$size_value ;;
      *) size_in_mb=0 ;;
    esac

    # Only mount partitions larger than 20 MB
    if (( $(echo "$size_in_mb >= 20" | bc -l) )); then
      mount_path="/mnt/$name"
      echo "Found unmounted data partition: $name ($size)"
      mkdir -p "$mount_path"
      if mount "/dev/$name" "$mount_path"; then
        chmod 755 "$mount_path"
        # Add Samba share with partition name as share name
        add_samba_share "$name" "$mount_path"
      else
        echo "Error mounting $name. Skipping..."
        rmdir "$mount_path"
      fi
    else
      echo "Skipping $name: Partition size below 20 MB."
    fi
  fi
done

# Restart Samba services to apply new shares
echo
echo "Restarting Samba services..."
sudo systemctl restart smbd nmbd
echo
echo "Samba shares configured. Available shares:"
grep -E '^\[.*\]$' "$SAMBA_CONF" | sed 's/[][]//g' | awk '{print " - \\\\" $1}'
echo
echo "All eligible partitions have been mounted and shared over Samba."
echo
echo "Note: If connecting from Windows, it can often prevent access if there were"
echo "previous connection attempts stored. To clear these:"
echo "   net use              # look for any connections to ths server"
echo "   net use <share> /d   # delete the share that is blocking the connection"
echo "Then go back into network and access the server by:"
echo "   \\<servername"
echo

