#!/bin/bash

# Function to convert human-readable sizes to bytes
convert_to_bytes() {
    SIZE=$1
    VALUE=$(echo "$SIZE" | sed -E 's/[^0-9.]//g')  # Values of form "1.8" etc
    UNIT=$(echo "$SIZE" | sed -E 's/[0-9.]*//g')   # Units of form "T" or "G" etc
    case "$UNIT" in
        T) MULTIPLIER=$((1024 ** 4)) ;;
        G) MULTIPLIER=$((1024 ** 3)) ;;
        M) MULTIPLIER=$((1024 ** 2)) ;;
        K) MULTIPLIER=1024 ;;
        *) MULTIPLIER=1 ;;
    esac
    echo "$(echo "$VALUE * $MULTIPLIER" | bc | awk '{printf "%.0f", $0}')"
}

# Function to ensure the filesystem is present
check_or_create_fs() {
    DEV=$1
    FS_TYPE=$(blkid -o value -s TYPE "$DEV")

    if [ -z "$FS_TYPE" ]; then
        echo -e "\033[33m$DEV is not formatted, creating ext4 filesystem...\033[0m"
        echo "Creating ext4 filesystem on $DEV..."
        sudo mkfs.ext4 "$DEV"
        # Format the partition
        # lazy_itable_init / lazy_journal_init will run those after the initial format
        # mkfs.ext4 -F -E lazy_itable_init=1,lazy_journal_init=1 -m 0 -O ^has_journal /dev/sdb1
        # -F              : Force formatting even if a filesystem exists.
        # -E lazy_*       : Initialize inode and journal tables lazily (after the initial format completes).
        # -m 0            : Reduce reserved space to 0%.
        # -O ^has_journal : Skip journaling.
        mkfs.ext4 -E lazy_itable_init=1,lazy_journal_init=1 "$DEV"
    elif [ "$FS_TYPE" != "ext4" ]; then
        echo -e "\033[33m$DEV has a $FS_TYPE filesystem, but this script requires ext4.\033[0m"
        # echo "Reformatting $DEV with ext4..."
        # sudo mkfs.ext4 "$DEV"
    fi
}

# Require root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo "$0" "$@"
fi

set -e
CURRENT_USER=${SUDO_USER:-$(whoami)}

# Install Samba if missing
if ! dpkg -l | grep -q samba; then
    echo "Installing Samba..."
    apt-get install -y samba
fi

# Backup existing smb.conf
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
cp /etc/samba/smb.conf "/etc/samba/smb.conf-$TIMESTAMP.bak"

# USER_HOME="/home/$CURRENT_USER"
# USER_SMB_NAME="home-$CURRENT_USER"
# 
# # Add home share if missing
# if ! grep -q "^\[$USER_SMB_NAME\]" /etc/samba/smb.conf; then
#     cat <<EOF >> /etc/samba/smb.conf
# 
# [$USER_SMB_NAME]
#    path = $USER_HOME
#    valid users = $CURRENT_USER
#    read only = no
#    browsable = yes
#    guest ok = no
#    create mask = 0777
#    directory mask = 0777
#    comment = Added by script
# EOF
# fi

NAS_COUNTER=1
lsblk -lnpo NAME,SIZE,MOUNTPOINT | grep -E '/dev/sd[a-d][1-9]' | while read -r DEV_NAME DEV_SIZE MOUNTPOINT; do
    DEV_SIZE_BYTES=$(convert_to_bytes "$DEV_SIZE")
    [ "$DEV_SIZE_BYTES" -lt 1073741824 ] && continue   # Skip small devices

    if [ -z "$MOUNTPOINT" ]; then
        MOUNTPOINT="/mnt/$(basename "$DEV_NAME")"
        echo "Creating mount point at $MOUNTPOINT"
        mkdir -p "$MOUNTPOINT"

        # Check and create filesystem if necessary
        check_or_create_fs "$DEV_NAME"

        # Ensure filesystem is mounted
        if ! mount | grep -q "$MOUNTPOINT"; then
            echo "Mounting $DEV_NAME at $MOUNTPOINT"
            mount "$DEV_NAME" "$MOUNTPOINT" || {
                echo -e "\033[31mFailed to mount $DEV_NAME. Exiting...\033[0m"
                exit 1
            }
        else
            echo "$DEV_NAME is already mounted at $MOUNTPOINT"
        fi

        echo "$MOUNTPOINT"

        # Ensure correct ownership and permissions, but skip if MOUNTPOINT is "/"
        if [ "$MOUNTPOINT" != "/" ]; then
            echo "Setting ownership and permissions for $MOUNTPOINT..."
            chown -R "$CURRENT_USER:$CURRENT_USER" "$MOUNTPOINT"
            chmod -R 777 "$MOUNTPOINT"
        else
            echo "Skipping chown and chmod for /"
        fi
    fi

    NAS_NAME="nas$NAS_COUNTER"
    COMMENT="Added by script, $DEV_NAME, $DEV_SIZE"
    NAS_COUNTER=$((NAS_COUNTER + 1))

    if ! grep -q "^\[$NAS_NAME\]" /etc/samba/smb.conf; then
        echo "Creating smb.conf entry $NAS_NAME for $MOUNTPOINT"
        echo "$COMMENT"
        cat <<EOF >> /etc/samba/smb.conf

[$NAS_NAME]
   path = $MOUNTPOINT
   valid users = $CURRENT_USER
   read only = no
   browsable = yes
   guest ok = no
   create mask = 0777
   directory mask = 0777
   comment = $COMMENT
EOF
    fi

#     # Handle root partition if /dev/sda1
#     [ "$DEV_NAME" == "/dev/sda1" ] && {
#         ROOT_SHARE="nas-root"
#         if ! grep -q "^\[$ROOT_SHARE\]" /etc/samba/smb.conf; then
#             cat <<EOF >> /etc/samba/smb.conf
# 
# [$ROOT_SHARE]
#    path = / 
#    valid users = root
#    read only = yes
#    browsable = yes
#    guest ok = no
#    create mask = 0777
#    directory mask = 0777
#    comment = Root partition - Read only
# EOF
#         fi
#     }
done

# Set Samba password
echo "Setting Samba password for $CURRENT_USER..."
smbpasswd -a "$CURRENT_USER"
# echo -e "$CURRENT_USER\n$CURRENT_USER" | sudo smbpasswd -s -a "$CURRENT_USER"

# Restart Samba and check for errors
echo "Restarting Samba service..."
systemctl restart smbd || {
    echo -e "\033[31mSamba failed to restart. Checking configuration...\033[0m"
    testparm
    echo "Samba logs:"
    journalctl -xeu smbd.service | tail -20
    exit 1
}
echo "Enable Samba to ensure the service starts on reboot..."
systemctl enable smbd

# Open firewall ports if UFW is active
if systemctl is-active --quiet ufw && ! ufw status | grep -q "Samba"; then
    echo "Allowing Samba through UFW firewall..."
    ufw allow samba
fi

cat <<EOF
Samba shares configured. Access them via '\\\\<IP>\\<share-name>'.
sudo systemctl enable smbd
sudo systemctl restart smbd
sudo systemctl restart nmbd
sudo systemctl disable samba-ad-dc.service   # Used for AD, not for samba shares

Troubleshooting from Windows:
To fully disconnect Windows from <IP> when connection issues:
net use     # list all active network connections
net use <IP> /delete /y   # Force disconnect all connections to <IP>
net use * /delete /y      # Force disconnect all connections from all hosts
cmdkey /list              # List cached credentials that may interfere with connections
cmdkey /delete:<IP>       # Remove all credentials for an IP
ipconfig /flushdns        # Flush DNS & Network Cache to refresh the network stack
nbtstat -R                
nbtstat -RR
netsh int ip reset
netsh winsock reset
Finally, restart your computer and retest connections.
net use \\192.168.1.140 /user:boss   # Use the samba username here
net use X: \\192.168.1.140\nas1 /user:boss
This should fully disconnect and allow a clean reconnection. 🚀
detailed logging through journalctl for service start
-u for specific logs, -f to follow new logs in real-time:
journalctl -fu smbd

EOF
