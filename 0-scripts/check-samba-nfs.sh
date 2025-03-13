#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No color

echo
# Check if Samba is installed
if systemctl list-unit-files | grep -q smbd.service; then
    echo -e "${GREEN}Samba is installed.${NC}"
else
    echo -e "${RED}Samba is NOT installed or the smbd service is missing.${NC}"
    echo -e "${RED}To install Samba: sudo apt install samba${NC}"
fi

echo "To restart Samba: sudo systemctl restart smbd"
echo "To check Samba shares: smbclient -L localhost -U%"
echo "To check Samba status: sudo systemctl status smbd"
echo ""
echo "Note: Samba consists of two main services:"
echo "  - smbd: Handles file sharing and authentication."
echo "  - nmbd: Handles NetBIOS name resolution, allowing Windows machines to find the Samba server by name."
echo "    (Restart it if you are having name resolution issues: sudo systemctl restart nmbd)"
echo ""

# Check if NFS is installed
if systemctl list-unit-files | grep -q nfs-server.service; then
    echo -e "${GREEN}NFS is installed.${NC}"
else
    echo -e "${RED}NFS is NOT installed.${NC}"
    echo -e "${RED}To install NFS: sudo apt install nfs-kernel-server${NC}"
fi

echo "To restart NFS: sudo systemctl restart nfs-server"
echo "To check NFS exports: exportfs -v"
echo "To check NFS status: sudo systemctl status nfs-server"

