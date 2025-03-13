#!/bin/bash

# Get the real home directory of the user invoking sudo
USER_HOME=$(eval echo ~$(logname))
OUTPUT_FILE="$USER_HOME/system-shares.txt"

# Add date/time to the output file
echo "=== System Shares Report ===" > "$OUTPUT_FILE"
echo "Generated on: $(date)" >> "$OUTPUT_FILE"
echo "Host: $(hostname)" >> "$OUTPUT_FILE"
echo "-------------------------------------------" >> "$OUTPUT_FILE"

# Mounted non-zero size filesystems
echo -e "\n--- Mounted Non-Zero Size Filesystems ---" >> "$OUTPUT_FILE"
echo -e "findmnt -o SIZE,USE%,TARGET,SOURCE,FSTYPE,OPTIONS | grep -v \"^[[:space:]]*0\"" >> "$OUTPUT_FILE"
# findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS ---" >> "$OUTPUT_FILE"
findmnt -o SIZE,USE%,TARGET,SOURCE,FSTYPE,OPTIONS | grep -v "^[[:space:]]*0" >> "$OUTPUT_FILE"
# findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS >> "$OUTPUT_FILE"

echo -e "\n--- Block Devices & Filesystems:   lsblk -f ---" >> "$OUTPUT_FILE"
lsblk -f >> "$OUTPUT_FILE"

# Samba Shares (Outgoing)
echo -e "\n--- Samba Shares (Hosted):   testparm -s 2>/dev/null ---" >> "$OUTPUT_FILE"
testparm -s 2>/dev/null >> "$OUTPUT_FILE"

echo -e "\n--- Active Samba Connections:   smbstatus 2>/dev/null---" >> "$OUTPUT_FILE"
smbstatus 2>/dev/null >> "$OUTPUT_FILE"

# Samba Shares (Incoming)
echo -e "\n--- Samba Shares (Mounted):   mount | grep cifs ---" >> "$OUTPUT_FILE"
mount | grep cifs >> "$OUTPUT_FILE"

# NFS Shares (Outgoing)
echo -e "\n--- NFS Exports (Hosted):   cat /etc/exports 2>/dev/null ---" >> "$OUTPUT_FILE"
cat /etc/exports 2>/dev/null >> "$OUTPUT_FILE"

# NFS Shares (Incoming)
echo -e "\n--- NFS Shares (Mounted):   showmount -e localhost 2>/dev/null ---" >> "$OUTPUT_FILE"
showmount -e localhost 2>/dev/null >> "$OUTPUT_FILE"
mount | grep nfs >> "$OUTPUT_FILE"

# Active SMB & NFS Connections
echo -e "\n--- Active SMB & NFS Connections:   ss -tuna | grep -E '445|2049' ---" >> "$OUTPUT_FILE"
echo -r "--- Active network connections for SMB (port 445) and NFS (port 2049). ---" >> "$OUTPUT_FILE"
ss -tuna | grep -E '445|2049' >> "$OUTPUT_FILE"

# Permissions of common share locations
echo -e "\n--- Share Permissions ---" >> "$OUTPUT_FILE"
for dir in /srv/samba /mnt /media /home/*/Public /var/nfs /export; do
    if [ -d "$dir" ]; then
        echo -e "\nPermissions for $dir:" >> "$OUTPUT_FILE"
        ls -ld "$dir" >> "$OUTPUT_FILE"
    fi
done

# Extra System Info
echo -e "\n--- Extra System Info ---" >> "$OUTPUT_FILE"
echo "Uptime: $(uptime -p)" >> "$OUTPUT_FILE"
echo "Disk Usage:" >> "$OUTPUT_FILE"
df -hT >> "$OUTPUT_FILE"

# Final message
echo -e "\nReport saved to: $OUTPUT_FILE"

cat $OUTPUT_FILE

