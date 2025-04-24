#!/bin/bash

# ───────────────────────────────────────────────────────────────
# Syncthing Server Setup in Docker (for Linux) - Host Network Mode
# Author: You! (Improved by AI)
# Description: Sets up a Syncthing container using host networking
#              for better local discovery and guides on adding folders.
# ───────────────────────────────────────────────────────────────

# ───[ Styling ]─────────────────────────────────────────────────
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ───[ Configuration ]───────────────────────────────────────────
# !! IMPORTANT: Define ALL host directories you might want Syncthing to access here !!
# Syncthing running inside Docker can ONLY see directories explicitly mounted using '-v'.
# Add more lines like the 'TORRENTS_DIR' example if you have other separate areas to sync.
# --- Default Host directory for Syncthing's configuration files ---
# (contains database, keys, settings - KEEP THIS SAFE!)
ST_HOST_CONFIG_DIR="$HOME/.config/syncthing-docker" # Changed slightly to avoid conflict if native Syncthing is also used
# --- Host directory for your completed torrents ---
# Make sure this path exists on your host machine!
TORRENTS_HOST_DIR="/mnt/sdc1/Downloads/0-torrents-complete"
# You can add more directories here if needed, e.g.:
# PHOTOS_HOST_DIR="/path/to/my/photos"
# DOCUMENTS_HOST_DIR="/path/to/my/documents"

# --- Container Settings ---
CONTAINER_NAME="syncthing"
SYNCTHING_IMAGE="syncthing/syncthing:latest"

# ───[ Helper Functions ]────────────────────────────────────────
# Function to check if a directory exists
check_dir() {
  if [ ! -d "$1" ]; then
    echo -e "${RED}✖ Error: Directory not found: $1${NC}"
    echo -e "${YELLOW}Please ensure the directory exists and the script has permission to access it.${NC}"
    exit 1
  fi
}

# ───[ Preparations ]────────────────────────────────────────────
echo -e "${BOLD}Syncthing Docker Setup (Host Network Mode)${NC}"
echo "--------------------------------------------------"

# --- Detect Host IP (Best guess for UI link) ---
# Note: With host networking, Syncthing binds to 0.0.0.0 (all interfaces)
# We still try to find a primary local IP for easy access link.
HOST_IP=$(hostname -I | awk '{print $1}')
if [ -z "$HOST_IP" ]; then
    echo -e "${YELLOW}⚠️ Could not automatically detect a primary local IP. You might need to find it manually (e.g., using 'ip a').${NC}"
    # Fallback if hostname -I fails
    HOST_IP="localhost"
fi
echo -e "${CYAN}ℹ️ Detected likely local IP: ${HOST_IP}${NC} (Syncthing UI will be accessible via this IP on port 8384)"

# --- Create Configuration Directory ---
echo -e "${CYAN}Ensuring Syncthing config directory exists on host: ${ST_HOST_CONFIG_DIR}${NC}"
mkdir -p "$ST_HOST_CONFIG_DIR"
if [ $? -ne 0 ]; then
  echo -e "${RED}✖ Error: Failed to create config directory: $ST_HOST_CONFIG_DIR${NC}"
  exit 1
fi

# --- Check if specified Host Data Directories exist ---
echo -e "${CYAN}Checking if specified host data directories exist...${NC}"
check_dir "$TORRENTS_HOST_DIR"
# Add checks for other directories if you defined them above, e.g.:
# check_dir "$PHOTOS_HOST_DIR"
# check_dir "$DOCUMENTS_HOST_DIR"
echo -e "${GREEN}✅ Host directories checked.${NC}"

# ───[ Docker Operations ]───────────────────────────────────────
echo
echo -e "${CYAN}Pulling latest Syncthing image ('${SYNCTHING_IMAGE}')...${NC}"
docker pull ${SYNCTHING_IMAGE}
if [ $? -ne 0 ]; then
  echo -e "${RED}✖ Error: Failed to pull Docker image. Check Docker installation and internet connection.${NC}"
  exit 1
fi

echo -e "${CYAN}Stopping and removing existing container named '$CONTAINER_NAME' (if any)...${NC}"
docker stop "$CONTAINER_NAME" > /dev/null 2>&1
docker rm "$CONTAINER_NAME" > /dev/null 2>&1

echo -e "${CYAN}Creating and starting Syncthing container '$CONTAINER_NAME'...${NC}"

# --- Build the docker run command ---
# Start with the basic command and options
DOCKER_CMD="docker run -d --name \"$CONTAINER_NAME\""
DOCKER_CMD+=" --network=host" # Use host network mode
DOCKER_CMD+=" --restart unless-stopped"
# --- Mount Essential Syncthing Configuration Volume ---
# This maps the host directory (where config is stored) to the container's internal path for config.
DOCKER_CMD+=" -v \"$ST_HOST_CONFIG_DIR:/var/syncthing/config\"" # Syncthing expects its config here
# --- Mount Data Volumes ---
# IMPORTANT: For every host directory you want Syncthing to potentially access,
# you MUST add a '-v' mount here. The container path (after the colon ':')
# is what you will use when adding a folder inside the Syncthing Web UI.
# We use a '/sync/' prefix inside the container for clarity.
# --- Mount the Torrents directory ---
DOCKER_CMD+=" -v \"$TORRENTS_HOST_DIR:/sync/0-torrents-complete\""
# Add more mounts here if you defined more directories above, e.g.:
# DOCKER_CMD+=" -v \"$PHOTOS_HOST_DIR:/sync/photos\""
# DOCKER_CMD+=" -v \"$DOCUMENTS_HOST_DIR:/sync/documents\""
# --- Add the Image Name ---
DOCKER_CMD+=" ${SYNCTHING_IMAGE}"

# --- Execute the command ---
echo -e "${YELLOW}Executing Docker command:${NC}"
echo "$DOCKER_CMD"
eval "$DOCKER_CMD" # Use eval to correctly handle quotes in paths

# --- Check for errors ---
if [ $? -ne 0 ]; then
  echo -e "${RED}✖ Failed to start Syncthing container. Check Docker logs:${NC}"
  echo -e "  ${CYAN}docker logs $CONTAINER_NAME${NC}"
  exit 1
fi

# ───[ Post-Setup Information ]──────────────────────────────────
echo
echo -e "${GREEN}✅ Syncthing container '$CONTAINER_NAME' started successfully!${NC}"
echo
echo -e "${BOLD}📍 Key Information:${NC}"
echo -e "- Container Name: ${CYAN}$CONTAINER_NAME${NC}"
echo -e "- Network Mode: ${YELLOW}host${NC} (Uses host's network directly)"
echo -e "- Config stored on host: ${CYAN}$ST_HOST_CONFIG_DIR${NC}"
echo -e "- Syncthing Image: ${CYAN}${SYNCTHING_IMAGE}${NC}"

echo
echo -e "${BOLD}💾 Mounted Host Directories (accessible inside Syncthing UI):${NC}"
echo -e "  Host: ${CYAN}$TORRENTS_HOST_DIR${NC} -> Container: ${YELLOW}/sync/torrents-complete${NC}"
# List other mounted directories here if added:
# echo -e "  Host: ${CYAN}$PHOTOS_HOST_DIR${NC} -> Container: ${YELLOW}/sync/photos${NC}"
# echo -e "  Host: ${CYAN}$DOCUMENTS_HOST_DIR${NC} -> Container: ${YELLOW}/sync/documents${NC}"
echo -e "${BOLD}IMPORTANT:${NC} When adding a folder in the Syncthing Web UI, use the ${YELLOW}Container Path${NC} (e.g., /sync/torrents-complete)."

echo
echo -e "${BOLD}🌐 Access Syncthing Web UI:${NC} ${YELLOW}http://${HOST_IP}:8384${NC}"
echo -e "${BOLD}Note:${NC} If you are accessing this from the host machine itself, you can also use ${YELLOW}http://localhost:8384${NC} or ${YELLOW}http://127.0.0.1:8384${NC}."
echo -e "Initial setup might require creating an admin username/password in the UI (Settings -> GUI)."

echo
echo -e "${BOLD}✨ How to Add Your Sync Folders (via Web UI):${NC}"
echo -e "1. Open the Syncthing Web UI (${YELLOW}http://${HOST_IP}:8384${NC})."
echo -e "2. Click the ${GREEN}'+ Add Folder'${NC} button."
echo -e "3. ${BOLD}Folder Label:${NC} Give it a descriptive name (e.g., 'Completed Torrents')."
echo -e "4. ${BOLD}Folder Path:${NC} THIS IS CRUCIAL! Enter the path ${UNDERLINE}inside the container${NC} that you mounted earlier."
echo -e "   - For your torrents: Enter ${YELLOW}/sync/torrents-complete${NC}"
# Add examples for other mounts if configured
# echo -e "   - For photos: Enter ${YELLOW}/sync/photos${NC}"
echo -e "5. Go to the ${BOLD}'Sharing'${NC} tab to select which devices should sync this folder."
echo -e "6. Configure other options (Versioning, Ignore Patterns) as needed."
echo -e "7. Click ${GREEN}'Save'${NC}."
echo -e "8. Repeat for any other folders you mounted and want to sync."

echo
echo -e "${BOLD}📡 Networking Notes (Host Mode):${NC}"
echo -e "- Syncthing directly uses the host's network interfaces."
echo -e "- Ports used on the host: ${CYAN}8384${NC} (Web UI), ${CYAN}22000/TCP${NC} (Sync Protocol), ${CYAN}22000/UDP${NC} (Sync Protocol), ${CYAN}21027/UDP${NC} (Discovery)."
echo -e "- Local device discovery should work reliably now."
echo -e "- If accessing from outside your LAN, ensure your ${BOLD}host machine's firewall${NC} allows these ports (especially 22000 TCP/UDP)."
echo -e "- Port forwarding on your router would need to point to ${BOLD}your host machine's IP${NC} (${HOST_IP}) for these ports."

echo
echo -e "${BOLD}🛠 Common Syncthing Docker Commands:${NC}"
echo -e "  ${CYAN}docker logs -f $CONTAINER_NAME${NC}      - View live Syncthing logs"
echo -e "  ${CYAN}docker ps${NC}                      - Check if container is running"
echo -e "  ${CYAN}docker stop $CONTAINER_NAME${NC}       - Stop the container"
echo -e "  ${CYAN}docker start $CONTAINER_NAME${NC}      - Start the container"
echo -e "  ${CYAN}docker restart $CONTAINER_NAME${NC}    - Restart the container"
echo -e "  ${CYAN}docker rm -f $CONTAINER_NAME${NC}       - Force remove container (config ${BOLD}preserved${NC} in ${ST_HOST_CONFIG_DIR})"
echo -e "  ${CYAN}docker exec -it $CONTAINER_NAME sh${NC} - Enter container shell (usually Alpine 'sh', not 'bash')"

echo
echo -e "${BOLD}🔮 Adding NEW Host Folders Later:${NC}"
echo -e "If you want Syncthing to access a host folder that wasn't mounted initially:"
echo -e "1. ${RED}STOP${NC} the container: ${CYAN}docker stop $CONTAINER_NAME${NC}"
echo -e "2. ${RED}REMOVE${NC} the container: ${CYAN}docker rm $CONTAINER_NAME${NC} (Your config in ${ST_HOST_CONFIG_DIR} is safe!)"
echo -e "3. Edit ${BOLD}this script${NC}:"
echo -e "   - Add a new variable for the host path (e.g., ${CYAN}NEW_FOLDER_HOST_DIR=\"/path/to/new/folder\"${NC})."
echo -e "   - Add a new ${CYAN}check_dir \"\$NEW_FOLDER_HOST_DIR\"${NC} line."
echo -e "   - Add a new mount line to the ${CYAN}DOCKER_CMD${NC} string: ${CYAN}-v \"\$NEW_FOLDER_HOST_DIR:/sync/new-folder-name\"${NC}"
echo -e "   - Update the '${BOLD}Mounted Host Directories'${NC} output section."
echo -e "4. ${GREEN}Re-run this script${NC}. It will recreate the container with the new mount."
echo -e "5. Go to the Web UI and add the new folder using its container path (e.g., ${YELLOW}/sync/new-folder-name${NC})."

echo
echo -e "${GREEN}🚀 Setup complete. Configure your folders and devices via the Web UI!${NC}"
