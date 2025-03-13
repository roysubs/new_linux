#!/bin/bash

# ANSI color codes
YELLOW='\e[1;33m'
GREEN='\e[1;32m'
RESET='\e[0m'

# Get the real home directory of the user invoking sudo
USER_HOME=$(eval echo ~$(logname))
OUTPUT_FILE="$USER_HOME/system-shares.txt"

# Add date/time to the output file
echo -e "\e[33m=== System Shares Report ===\e[0m" | tee "$OUTPUT_FILE"
echo "Generated on: $(date)" | tee -a "$OUTPUT_FILE"
echo "Host: $(hostname)" | tee -a "$OUTPUT_FILE"
echo "-------------------------------------------" | tee -a "$OUTPUT_FILE"

# Mounted non-zero size filesystems
echo -e "\e[33m--- Mounted Filesystems with Non-Zero Size ---\e[0m" | tee -a "$OUTPUT_FILE"
echo -e "\e[32mfindmnt -o SIZE,USE%,TARGET,SOURCE,FSTYPE,OPTIONS | grep -v \"^[[:space:]]*0\"\e[0m" | tee -a "$OUTPUT_FILE"
findmnt -o SIZE,USE%,TARGET,SOURCE,FSTYPE,OPTIONS | grep -v "^[[:space:]]*0" | tee -a "$OUTPUT_FILE"

# Block Devices & Filesystems
echo -e "\e[33m--- Block Devices & Filesystems ---\e[0m" | tee -a "$OUTPUT_FILE"
echo -e "\e[32mlsblk -f\e[0m" | tee -a "$OUTPUT_FILE"
lsblk -f | tee -a "$OUTPUT_FILE"

# Samba Shares (Outgoing)
echo -e "\e[33m--- Samba Shares (Hosted) ---\e[0m" | tee -a "$OUTPUT_FILE"
echo -e "\e[32mtestparm -s -v 2>/dev/null | grep -E '^[[:space:]]*path'\e[0m" | tee -a "$OUTPUT_FILE"
testparm -s -v 2>/dev/null | grep -E '^[[:space:]]*path' | tee -a "$OUTPUT_FILE" || echo "(Command not found)" | tee -a "$OUTPUT_FILE"

# Active Samba Connections
echo -e "\e[33m--- Active Samba Connections ---\e[0m" | tee -a "$OUTPUT_FILE"
echo -e "\e[32msmbstatus -b 2>/dev/null\e[0m" | tee -a "$OUTPUT_FILE"
smbstatus -b 2>/dev/null | tee -a "$OUTPUT_FILE" || echo "(Command not found)" | tee -a "$OUTPUT_FILE"

# Samba Shares (Incoming)
echo -e "\e[33m--- Samba Shares (Mounted) ---\e[0m" | tee -a "$OUTPUT_FILE"
echo -e "\e[32mmount | grep cifs\e[0m" | tee -a "$OUTPUT_FILE"
mount | grep cifs | tee -a "$OUTPUT_FILE"

# NFS Shares (Outgoing)
echo -e "\e[33m--- NFS Exports (Hosted) ---\e[0m" | tee -a "$OUTPUT_FILE"
echo -e "\e[32mexportfs -v 2>/dev/null\e[0m" | tee -a "$OUTPUT_FILE"
exportfs -v 2>/dev/null | tee -a "$OUTPUT_FILE" || echo "(Command not found)" | tee -a "$OUTPUT_FILE"

# NFS Shares (Incoming)
echo -e "\e[33m--- NFS Shares (Mounted) ---\e[0m" | tee -a "$OUTPUT_FILE"
echo -e "\e[32mshowmount -e localhost 2>/dev/null\e[0m" | tee -a "$OUTPUT_FILE"
showmount -e localhost 2>/dev/null | tee -a "$OUTPUT_FILE" || echo "(Command not found)" | tee -a "$OUTPUT_FILE"
mount | grep nfs | tee -a "$OUTPUT_FILE"

# Active SMB & NFS Connections
echo -e "\e[33m--- Active SMB & NFS Connections ---\e[0m" | tee -a "$OUTPUT_FILE"
echo -e "\e[32mss -tuna | grep -E '445|2049'\e[0m" | tee -a "$OUTPUT_FILE"
ss -tuna | grep -E '445|2049' | tee -a "$OUTPUT_FILE"

# Permissions of common share locations
echo -e "\e[33m--- Share Permissions ---\e[0m" | tee -a "$OUTPUT_FILE"
for dir in /srv/samba /mnt /media /home/*/Public /var/nfs /export; do
    if [ -d "$dir" ]; then
        echo -e "\nPermissions for $dir:" | tee -a "$OUTPUT_FILE"
        ls -ld "$dir" | tee -a "$OUTPUT_FILE"
    fi
done

# Extra System Info
echo -e "\e[33m--- Extra System Info ---\e[0m" | tee -a "$OUTPUT_FILE"
echo "Uptime: $(uptime -p)" | tee -a "$OUTPUT_FILE"
echo "Disk Usage:" | tee -a "$OUTPUT_FILE"
df -hT | tee -a "$OUTPUT_FILE"

# Final message
echo -e "\e[32m\nReport saved to: $OUTPUT_FILE\e[0m"

cat "$OUTPUT_FILE"

