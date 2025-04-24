#!/bin/bash

# ────────────────────────────────────────────────
# Plex Media Server Setup in Docker (for Linux)
# Author: You!
# Description: Automates deployment of Plex Media Server in Docker.
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

# ──[ Prompt for Media Directory ]─────────────────
echo
echo -e "${BOLD}Please enter the root folder where your media is stored.${NC}"
echo -e "Use Tab to autocomplete. Example: /mnt/sdc1/Downloads"
read -e -p "Enter media root path: " MEDIA_DIR

# ──[ Validate Media Directory ]───────────────────
if [ ! -d "$MEDIA_DIR" ]; then
  echo -e "${RED}Error: Directory not found: $MEDIA_DIR${NC}"
  exit 1
fi

# ──[ Create Standard Media Folders ]──────────────
for folder in "0 Films" "0 TV" "0 Music"; do
  mkdir -p "$MEDIA_DIR/$folder"
done

# ──[ Show Folder Mapping Explanation ]────────────
echo
echo -e "${BOLD}📁 Folder Mapping Info:${NC}"
echo -e "The Docker container will map your media folder to: ${YELLOW}/mnt/plex/media${NC}"
echo -e "This means inside Plex you will use paths like:${NC}"
echo -e "  /mnt/plex/media/0 Films"
echo -e "  /mnt/plex/media/0 TV"
echo -e "  /mnt/plex/media/0 Music"

# ──[ Container Settings ]─────────────────────────
CONTAINER_NAME="plex-media-server"

# ──[ Check for Existing Container ]───────────────
EXISTS=$(docker ps -a --format '{{.Names}}' | grep -w "$CONTAINER_NAME")

# ──[ Get Plex Claim Code If Needed ]──────────────
if [ -z "$EXISTS" ]; then
  echo
  echo -e "${BOLD}To link this server to your Plex account:${NC}"
  echo -e "  1. Visit ${YELLOW}https://account.plex.tv/claim${NC}"
  echo -e "  2. Sign in and copy your claim code (starts with 'claim-')"
  echo -e "  3. Paste it below. Code is valid for 5 minutes."
  echo
  read -p "Enter your Plex claim code: " PLEX_CLAIM

  echo -e "${CYAN}Pulling latest Plex image...${NC}"
  docker pull plexinc/pms-docker

  echo -e "${CYAN}Creating Plex container...${NC}"
  docker run -d --name $CONTAINER_NAME \
    -e PLEX_CLAIM="$PLEX_CLAIM" \
    -e ADVERTISE_IP="http://$HOST_IP:32400" \
    -v "$MEDIA_DIR:/mnt/plex/media" \
    -v plex_data:/config \
    -p 32400:32400 \
    --restart unless-stopped \
    plexinc/pms-docker

  if [ $? -ne 0 ]; then
    echo -e "${RED}✖ Failed to start Plex container. Check Docker logs.${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}Container '$CONTAINER_NAME' already exists.${NC}"
fi

# ──[ Post-Setup Info (Always Shown) ]─────────────
echo
echo -e "${BOLD}📍 Plex Container Info:${NC}"
echo -e "- Container name: ${CYAN}$CONTAINER_NAME${NC}"
echo -e "- Media folder on host: ${CYAN}$MEDIA_DIR${NC}"
echo -e "- Mapped inside container to: ${CYAN}/mnt/plex/media${NC}"
echo
echo -e "${BOLD}📁 Suggested Plex Library Setup:${NC}"
for folder in "${SUBFOLDERS[@]}"; do
  type=$(echo "$folder" | sed 's/^0 //')
  echo "  Library Type: $type -> /mnt/plex/media/$folder"
done
echo
echo -e "${BOLD}🔧 Container Management:${NC}"
echo -e "  ${CYAN}docker restart $CONTAINER_NAME${NC}     - Restart the Plex container"
echo -e "  ${CYAN}docker logs $CONTAINER_NAME${NC}        - View logs"
echo -e "  ${CYAN}docker exec -it $CONTAINER_NAME bash${NC} - Enter the container shell"
echo
echo -e "${BOLD}🌐 Access Plex Web UI:${NC} http://${HOST_IP}:32400/web"

