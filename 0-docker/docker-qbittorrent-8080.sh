#!/bin/bash

# qBittorrent Docker automated deployment script
# Based on Linuxserver.io image: https://docs.linuxserver.io/images/docker-qbittorrent/
# ───────────────────────────────────────────────────────────────

# ───[ Styling ]─────────────────────────────────────────────────
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BLUE_BOLD='\033[1;34m\033[1m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ───[ Configuration ]───────────────────────────────────────────
DEFAULT_DOWNLOADS_DIR="/mnt/sdc1/Downloads"
DEFAULT_CONFIG_DIR="$HOME/.config/qbittorrent-docker"
CONTAINER_NAME="qbittorrent"
QBITTORRENT_IMAGE="lscr.io/linuxserver/qbittorrent:latest"
WEBUI_PORT=8080
TORRENTING_PORT=6881
PUID=$(id -u)
PGID=$(id -g)
TIMEZONE="Etc/UTC"

# ───[ Preparations ]────────────────────────────────────────────
echo -e "${BOLD}qBittorrent Docker Setup${NC}"
echo "--------------------------------------------------"

# --- Ask user for Downloads directory ---
echo -e "${BOLD}Please enter the host folder to be used for qBittorrent downloads.${NC}"
echo -e "You can use 'tab' to autocomplete paths."
echo -e "Leave empty to use default: ${BLUE_BOLD}${DEFAULT_DOWNLOADS_DIR}${NC}"
read -e -p "Enter Downloads folder path [${DEFAULT_DOWNLOADS_DIR}]: " user_input
if [ -z "$user_input" ]; then
  HOST_DOWNLOADS_DIR="$DEFAULT_DOWNLOADS_DIR"
  echo -e "Using default downloads path: ${BLUE_BOLD}${HOST_DOWNLOADS_DIR}${NC}"
else
  HOST_DOWNLOADS_DIR="$user_input"
  echo -e "Using entered downloads path: ${BLUE_BOLD}${HOST_DOWNLOADS_DIR}${NC}"
fi

# Check if downloads directory exists
if [ ! -d "$HOST_DOWNLOADS_DIR" ]; then
  echo -e "${RED}${BOLD}Error: The path ${BLUE_BOLD}$HOST_DOWNLOADS_DIR${RED}${BOLD} does not exist.${NC}"
  echo -e "${YELLOW}Please create it first or rerun the script with a valid path.${NC}"
  exit 1
fi

# Ensure config directory exists
mkdir -p "$DEFAULT_CONFIG_DIR"

# --- Detect Host IP (Best guess for WebUI link) ---
HOST_IP=$(hostname -I | awk '{print $1}')
if [ -z "$HOST_IP" ]; then
  echo -e "${YELLOW}⚠️ Could not automatically detect a primary local IP. Will use localhost instead.${NC}"
  HOST_IP="localhost"
fi
echo -e "${CYAN}ℹ️ Detected likely local IP: ${HOST_IP}${NC} (WebUI will be accessible via this IP on port ${WEBUI_PORT})"

# ───[ Deployment ]──────────────────────────────────────────────
echo -e "${BOLD}Starting Docker container...${NC}"

docker run -d \
  --name="$CONTAINER_NAME" \
  -e PUID="$PUID" \
  -e PGID="$PGID" \
  -e TZ="$TIMEZONE" \
  -e WEBUI_PORT="$WEBUI_PORT" \
  -e TORRENTING_PORT="$TORRENTING_PORT" \
  -p "$WEBUI_PORT:$WEBUI_PORT" \
  -p "$TORRENTING_PORT:$TORRENTING_PORT" \
  -p "$TORRENTING_PORT:$TORRENTING_PORT/udp" \
  -v "$DEFAULT_CONFIG_DIR:/config" \
  -v "$HOST_DOWNLOADS_DIR:/downloads" \
  --restart unless-stopped \
  "$QBITTORRENT_IMAGE"

# ───[ Info for the User ]────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}✅ qBittorrent Docker container deployed successfully!${NC}"
echo ""
echo -e "${CYAN}WebUI Access:${NC} http://${HOST_IP}:${WEBUI_PORT}"
echo ""
echo -e "${YELLOW}Important First Time Setup:${NC}"
echo -e "- On first run, a random temporary admin password will be printed in the container logs."
echo -e "- You must login and change the username and password immediately."
echo -e "- To view the temporary password, run:"
echo -e "    ${BOLD}docker logs ${CONTAINER_NAME}${NC}"
echo ""
echo -e "${YELLOW}Ports Used:${NC}"
echo -e "- WebUI: ${WEBUI_PORT}"
echo -e "- Torrent TCP/UDP: ${TORRENTING_PORT}"
echo ""
echo -e "${YELLOW}Volumes Used:${NC}"
echo -e "- ${DEFAULT_CONFIG_DIR} (persistent configuration)"
echo -e "- ${HOST_DOWNLOADS_DIR} (Downloads folder)"
echo ""
echo -e "${YELLOW}Additional Notes:${NC}"
echo "- If you need to change the WebUI port or Torrent port later, you must:"
echo "  Update the docker container mapping *and* the corresponding -e variables."
echo "- The container runs with your current user UID:GID (${PUID}:${PGID}) for correct permissions."
echo "- To remove container:"
echo "    ${BOLD}docker rm -f ${CONTAINER_NAME}${NC}"
echo "- To update container image later:"
echo "    ${BOLD}docker pull ${QBITTORRENT_IMAGE}${NC} then recreate."

echo ""
echo -e "${GREEN}${BOLD}Done! 🎉${NC}"

