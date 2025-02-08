#!/bin/bash

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo "$0" "$@"
fi

# Function to check if a service is active
is_service_active() {
  systemctl is-active --quiet "$1"
}

# Function to list Samba shares with permissions
list_samba_shares() {
  if is_service_active smbd; then
    echo "Samba Shares (Server Mode):"
    echo -e "Sharename\tPath\tRO\tCreateMask\tDirMask"
    echo "--------------------------------------------------------------------------------------"

    # Read the smb.conf file and extract shares
    if [ -f /etc/samba/smb.conf ]; then
      awk '
      BEGIN { in_share=0; share_name=""; path=""; create_mask=""; dir_mask=""; read_only=""; }
      /^\[/ {
        if (in_share) {
          if (share_name ~ /global|homes|print\$|printers/) {
            print share_name "\t<default>\t" (read_only ? read_only : "undefined") "\t" create_mask "\t" dir_mask;
          } else {
            print share_name "\t" path "\t" (read_only ? read_only : "undefined") "\t" create_mask "\t" dir_mask;
          }
        }
        in_share=1;
        share_name=$0;
        gsub(/\[|\]/, "", share_name);
        path=""; create_mask=""; dir_mask=""; read_only="";
      }
      /path[[:space:]]*=/ { gsub(/path[[:space:]]*=[[:space:]]*/, ""); path=$0; }
      /read only[[:space:]]*=/ { gsub(/read only[[:space:]]*=[[:space:]]*/, ""); read_only=$0; }
      /create mask[[:space:]]*=/ { gsub(/create mask[[:space:]]*=[[:space:]]*/, ""); create_mask=$0; }
      /directory mask[[:space:]]*=/ { gsub(/directory mask[[:space:]]*=[[:space:]]*/, ""); dir_mask=$0; }
      END {
        if (in_share) {
          if (share_name ~ /global|homes|print\$|printers/) {
            print share_name "\t<default>\t" (read_only ? read_only : "undefined") "\t" create_mask "\t" dir_mask;
          } else {
            print share_name "\t" path "\t" (read_only ? read_only : "undefined") "\t" create_mask "\t" dir_mask;
          }
        }
      }
      ' /etc/samba/smb.conf | column -t
    fi

    # Show active Samba connections
    echo -e "\nActive Samba Connections (Clients Connected to This System):"
    smbstatus -S 2>/dev/null | awk 'NR > 1 {print $1, $2, $3, $4}' | column -t || echo "No active connections."

    # Show Samba service status
    echo -e "\nSamba Service Status:"
    systemctl status smbd --no-pager | grep -E 'Active|Loaded'
  else
    echo "Samba is not active."
  fi
}

# Function to list NFS shares (Server Mode)
list_nfs_shares() {
  if is_service_active nfs-server; then
    echo -e "\nNFS Shares (Server Mode):"
    grep -v '^#' /etc/exports | awk '{print $1, $2}' | column -t

    # Show active NFS connections
    echo -e "\nActive NFS Connections (Clients Connected to This System):"
    showmount -a 2>/dev/null || echo "showmount command not available."

    # Show NFS service status
    echo -e "\nNFS Service Status:"
    systemctl status nfs-server --no-pager | grep -E 'Active|Loaded'
  else
    echo "NFS is not active."
  fi
}

# Function to list outgoing shares (NFS and SMB mounts on this system)
list_outgoing_shares() {
  echo -e "\nOutgoing Shares (This System as Client):"

  # Check for mounted SMB/CIFS shares
  smb_shares=$(mount -t cifs 2>/dev/null)
  if [[ -n "$smb_shares" ]]; then
    echo -e "\nSamba (SMB/CIFS) Mounts:"
    mount -t cifs | awk '{print $1, "mounted on", $3}'
  else
    echo "No Samba (SMB/CIFS) mounts found."
  fi

  # Check for mounted NFS shares
  nfs_shares=$(mount -t nfs 2>/dev/null)
  if [[ -n "$nfs_shares" ]]; then
    echo -e "\nNFS Mounts:"
    mount -t nfs | awk '{print $1, "mounted on", $3}'
  else
    echo "No NFS mounts found."
  fi
}

# Main script
echo "Checking Samba and NFS Shares..."
list_samba_shares
list_nfs_shares
list_outgoing_shares

