#!/bin/bash

# ────────────────────────────────────────────────
# Syncthing Setup in Docker
# Description: Sets up Syncthing for use across multiple servers via Docker.
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

# ──[ Configurable Parameters ]────────────────────
SYNC_DIR="/mnt/syncdata"
CONTAINER_NAME="syncthing"
CONFIG_VOLUME="syncthing_config"

# ──[ Check if Sync Directory Exists ]─────────────
if [ ! -d "$SYNC_DIR" ]; then
  echo -e "${YELLOW}Creating sync directory at ${SYNC_DIR}${NC}"
  mkdir -p "$SYNC_DIR"
fi

# ──[ Check for Existing Container ]───────────────
if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
  echo -e "${YELLOW}Container '${CONTAINER_NAME}' already exists.${NC}"
  echo -e "${GREEN}Use the following commands to manage it:${NC}"
  echo "  docker start $CONTAINER_NAME"
  echo "  docker stop $CONTAINER_NAME"
  echo "  docker logs $CONTAINER_NAME"
  exit 0
fi

# ──[ Pull Syncthing Docker Image ]────────────────
echo -e "${CYAN}Pulling the latest Syncthing Docker image...${NC}"
docker pull syncthing/syncthing

# ──[ Start Syncthing Container ]──────────────────
echo -e "${CYAN}Starting Syncthing container...${NC}"
docker run -d --name "$CONTAINER_NAME" \
  -v "$SYNC_DIR:/var/syncthing" \
  -v "$CONFIG_VOLUME:/var/syncthing/config" \
  -p 8384:8384 -p 22000:22000/tcp -p 22000:22000/udp -p 21027:21027/udp \
  --restart unless-stopped \
  syncthing/syncthing:latest

# ──[ Post-Setup Instructions ]────────────────────
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✔ Syncthing container is up and running.${NC}"
  echo
  echo -e "${BOLD}🔗 Access the Syncthing Web UI:${NC}"
  echo -e "  ${CYAN}http://$HOST_IP:8384${NC}"
  echo -e "  Default GUI password: none (set one ASAP!)"
  echo
  echo -e "${BOLD}📁 Synced Folder:${NC}"
  echo -e "  Host:       ${YELLOW}$SYNC_DIR${NC}"
  echo -e "  In Docker:  ${CYAN}/var/syncthing${NC}"
  echo
  echo -e "${BOLD}📡 Port Info:${NC}"
  echo -e "  GUI:        8384"
  echo -e "  Sync TCP:   22000"
  echo -e "  Sync UDP:   22000"
  echo -e "  Discovery:  21027/UDP"
  echo
  echo -e "${BOLD}🧩 Syncing Across Devices:${NC}"
  echo "1. Repeat this setup on your other two remote servers."
  echo "2. Open the Web UI on each device."
  echo "3. Exchange Device IDs (shown on the GUI) and add them under 'Add Remote Device'."
  echo "4. Share a common folder by adding the same folder ID and path."
  echo
  echo -e "${YELLOW}Note:${NC} Syncthing does not use a central server. All devices talk directly or via relay."
  echo
  echo -e "${BOLD}📦 Managing Syncthing Container:${NC}"
  echo -e "  ${CYAN}docker restart $CONTAINER_NAME${NC}      - Restart container"
  echo -e "  ${CYAN}docker logs $CONTAINER_NAME${NC}         - View logs"
  echo -e "  ${CYAN}docker exec -it $CONTAINER_NAME bash${NC} - Open container shell"
else
  echo -e "${RED}✖ Failed to start Syncthing container. Check logs.${NC}"
  echo "Run: docker logs $CONTAINER_NAME"
fi

