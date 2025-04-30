#!/bin/bash

# ────────────────────────────────────────────────
# Syncthing Server Setup in Docker (for Linux)
# Author: You!
# Description: Sets up a Syncthing container for folder synchronization.
# ────────────────────────────────────────────────

# ──[ Styling ]────────────────────────────────────
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ──[ Detect Host IP ]─────────────────────────────
HOST_IP=$(hostname -I | awk '{print $1}')
echo -e "${CYAN}Detected local IP: ${HOST_IP}${NC}"

# ──[ Prompt for Sync Folder ]─────────────────────
echo
echo -e "${BOLD}Enter the full path to the folder you want to sync.${NC}"
echo -e "This folder will be shared and synced with other devices via Syncthing."
read -e -p "Enter sync folder path: " SYNC_FOLDER

if [ ! -d "$SYNC_FOLDER" ]; then
  echo -e "${RED}Error: Directory not found: $SYNC_FOLDER${NC}"
  exit 1
fi

# ──[ Container Settings ]─────────────────────────
CONTAINER_NAME="syncthing"
ST_HOST_CONFIG_DIR="$HOME/.config/syncthing"
mkdir -p "$ST_HOST_CONFIG_DIR"

# ──[ Pull and Run Container ]─────────────────────
echo
echo -e "${CYAN}Pulling latest Syncthing image...${NC}"
docker pull syncthing/syncthing

echo -e "${CYAN}Creating Syncthing container...${NC}"
docker run -d --name "$CONTAINER_NAME" \
  -v "$ST_HOST_CONFIG_DIR:/var/syncthing/config" \
  -v "$SYNC_FOLDER:/var/syncthing/data" \
  -p 8384:8384 \
  -p 22000:22000/tcp \
  -p 22000:22000/udp \
  -p 21027:21027/udp \
  --restart unless-stopped \
  syncthing/syncthing

if [ $? -ne 0 ]; then
  echo -e "${RED}✖ Failed to start Syncthing container. Check Docker logs.${NC}"
  exit 1
fi

# ──[ Post-Setup Info ]────────────────────────────
echo
echo -e "${BOLD}📍 Syncthing Container Info:${NC}"
echo -e "- Container name: ${CYAN}$CONTAINER_NAME${NC}"
echo -e "- Sync folder on host: ${CYAN}$SYNC_FOLDER${NC}"
echo -e "- Syncthing config stored at: ${CYAN}$ST_HOST_CONFIG_DIR${NC}"

echo
echo -e "${BOLD}🌐 Access Syncthing Web UI:${NC} ${YELLOW}http://${HOST_IP}:8384${NC}"
echo -e "From here, you can:"
echo -e "- Add remote devices via Device ID"
echo -e "- Share folders to those devices"
echo -e "- Set folders to 'Send & Receive', 'Send Only', or 'Receive Only'"
echo -e "- Enable encryption, versioning, ignore patterns, and more"

echo
echo -e "${BOLD}🛠 Common Syncthing Console Commands:${NC}"
echo -e "  ${CYAN}docker logs -f $CONTAINER_NAME${NC}          - View live Syncthing logs"
echo -e "  ${CYAN}docker exec -it $CONTAINER_NAME ash${NC}     - Enter container shell (Alpine)"
echo -e "  ${CYAN}docker restart $CONTAINER_NAME${NC}          - Restart the container"
echo -e "  ${CYAN}docker stop $CONTAINER_NAME${NC}             - Stop Syncthing"
echo -e "  ${CYAN}docker rm -f $CONTAINER_NAME${NC}            - Remove the container (data is preserved)"

echo
echo -e "${BOLD}📡 Networking Notes:${NC}"
echo -e "- Syncthing auto-discovers peers on the LAN via UDP (port 21027)"
echo -e "- TCP port 22000 is used for device-to-device sync"
echo -e "- You can forward ports for remote access, but Syncthing can also use relays if direct connection fails"

echo
echo -e "${BOLD}🧠 Tips to Get Started:${NC}"
echo -e "- Visit the Web UI from another device and add this server using its Device ID"
echo -e "- Accept folder share requests and keep folder paths consistent if possible"
echo -e "- Set the folder to 'Send & Receive' to keep things in sync"
echo -e "- Keep config backups if you tweak advanced settings"

echo
echo -e "${GREEN}✅ Syncthing container is up and running!${NC}"

