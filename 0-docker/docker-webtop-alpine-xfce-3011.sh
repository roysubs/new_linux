#!/bin/bash

# Webtop Alpine XFCE Docker automated deployment using ghcr.io/linuxserver/webtop
# This script sets up the container with specified host paths, ports, and user IDs.
# It uses the config volume for persistence and provides tips for interaction.
# Based on instructions from:
# https://fleet.linuxserver.io/image?name=webtop
# ───────────────────────────────────────────────────────────────

# Check if Docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker is not installed. Please install Docker and rerun."
    echo "See instructions: https://docs.docker.com/engine/install/"
    exit 1
fi

# ───[ Styling ]─────────────────────────────────────────────────
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BLUE_BOLD='\033[1;34m' # Used for default paths
BOLD='\033[1m'
NC='\033[0m' # No Color
UNDERLINE='\033[4m'

# ───[ Configuration ]───────────────────────────────────────────
# --- Container Settings ---
CONTAINER_NAME="webtop-alpine-xfce" # Name for the new container - Changed back as requested
# The Docker image to use. Using the 'latest' tag which maps to Alpine XFCE.
WEB_IMAGE="ghcr.io/linuxserver/webtop" # Using 'latest' tag based on previous error

# --- Default Host directory for Webtop ---
# Configuration directory (stores user profile, settings etc - KEEP THIS SAFE!)
DEFAULT_HOST_CONFIG_DIR="$HOME/.config/${CONTAINER_NAME}-docker" # Updated default path using the container name
# Removed DEFAULT_HOST_DOWNLOADS_DIR as it's no longer a separate mount

WEB_CONTAINER_CONFIG_DIR="/config" # Internal config path inside the container (fixed by linuxserver image)
# Removed WEB_CONTAINER_DOWNLOADS_DIR as it's no longer a separate mount

# --- Default Port Settings ---
# Using the single port specified in the provided docker run command.
# Format is HOST_PORT:CONTAINER_PORT for clarity.
WEBUI_HOST_PORT=3011 # Port for the Web UI (noVNC) as per the docker run command
WEBUI_CONTAINER_PORT=3000 # Internal container port for WebUI (standard LSIO webtop)

# Removed VNC_HOST_PORT and VNC_CONTAINER_PORT as they are not in the provided command

# --- Environment Settings ---
# Specify a timezone to use. See https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
TZ="Europe/London" # !! IMPORTANT: Set to "Europe/London" as per the provided command !!

# ───[ Helper Functions ]────────────────────────────────────────
# Function to check if a directory exists or create it
ensure_dir() {
    if [ ! -d "$1" ]; then
        echo -e "${CYAN}Ensuring directory exists on host: $1${NC}"
        mkdir -p "$1"
        if [ $? -ne 0 ]; then
            echo -e "${RED}✖ Error: Failed to create directory: $1${NC}"
            echo -e "${YELLOW}Please check permissions or create it manually.${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ Directory created or already exists.${NC}"
    else
        echo -e "${GREEN}✅ Directory already exists on host: $1${NC}"
    fi
}

# Function to get PUID and PGID of the current user
get_user_ids() {
    # Using explicit PUID/PGID from the provided command, not host user
    echo "1000:1000"
}

# ───[ Preparations ]────────────────────────────────────────────
echo -e "${BOLD}Webtop Alpine XFCE Docker Setup${NC}"
echo "--------------------------------------------------"

# --- Detect Host IP (Best guess for UI link) ---
HOST_IP=$(hostname -I | awk '{print $1}')
if [ -z "$HOST_IP" ]; then
    echo -e "${YELLOW}⚠️ Could not automatically detect a primary local IP. You might need to find it manually (e.g., using 'ip a').${NC}"
    # Fallback if hostname -I fails
    HOST_IP="localhost"
fi
echo -e "${CYAN}ℹ️ Detected likely local IP: ${HOST_IP}${NC}"

# --- Get User and Group IDs (Using hardcoded from the command) ---
USER_IDS=$(get_user_ids)
PUID=${USER_IDS%:*}
PGID=${USER_IDS#*:}
echo -e "${CYAN}ℹ️ Using PUID=${PUID} and PGID=${PGID} from the command for container user mapping.${NC}"
echo -e "${YELLOW}Ensure the host directories you map below are owned by this user/group (${PUID}:${PGID}) for correct permissions inside the container.${NC}"


# Check if the container already exists
if docker ps -a --format '{{.Names}}' | grep -wq "$CONTAINER_NAME"; then
    echo -e "${GREEN}✅ Container '$CONTAINER_NAME' already exists. Skipping creation.${NC}"
    echo -e "${CYAN}To stop and remove the existing container to create a new one:${NC}"
    echo -e "  ${CYAN}docker stop \"$CONTAINER_NAME\" > /dev/null 2>&1${NC}"
    echo -e "  ${CYAN}docker rm \"$CONTAINER_NAME\" > /dev/null 2>&1${NC}"
    # Set variables to defaults for info output even if container wasn't recreated
    HOST_CONFIG_DIR=$DEFAULT_HOST_CONFIG_DIR
    # Removed HOST_DOWNLOADS_DIR default setting
else
    # --- Prompt for Host Configuration Directory ---
    echo -e "\n${BOLD}Please enter the host folder for Webtop configuration files.${NC}"
    echo -e "This is where container settings, your home directory files (including Downloads), etc., will be stored persistently."
    echo -e "Leave this empty to use the default path: ${BLUE_BOLD}${DEFAULT_HOST_CONFIG_DIR}${NC}"
    read -e -p "Enter host config path [${DEFAULT_HOST_CONFIG_DIR}]: " user_config_input
    HOST_CONFIG_DIR="${user_config_input:-$DEFAULT_HOST_CONFIG_DIR}" # Use default if input is empty

    # Removed prompt for Downloads directory

    # --- Prompt for Password ---
    echo -e "\n${BOLD}${RED}!! IMPORTANT: Set a secure password for accessing the Webtop desktop !!${NC}"
    echo -e "${BOLD}You will use this password to log in via the web browser.${NC}"
    read -s -p "Enter your secure password: " ACCESS_PASSWORD # -s hides input
    echo # Print a newline after silent read

    # --- Ensure Host Directory Exists ---
    echo -e "\n${BOLD}Checking/Creating host config directory...${NC}"
    ensure_dir "$HOST_CONFIG_DIR"
    # Removed ensure_dir for Downloads directory
    echo -e "${GREEN}✅ Host directory checked/ensured.${NC}"
    echo

    # ───[ Docker Operations ]───────────────────────────────────────
    echo -e "${CYAN}Creating and starting Webtop Alpine XFCE container '$CONTAINER_NAME'...${NC}"
    # Update the message to reflect the specific tag being pulled
    echo -e "${CYAN}Pulling Webtop image ('${WEB_IMAGE}')...${NC}"
    docker pull "${WEB_IMAGE}" # Added quotes around WEB_IMAGE just in case
    if [ $? -ne 0 ]; then
        echo -e "${RED}✖ Error: Failed to pull Docker image.${NC}"
        echo -e "${RED}  The image pull command failed for '${WEB_IMAGE}'. Ensure the image name and tag are correct and that you have network connectivity to ghcr.io.${NC}"
        exit 1
    fi

    # --- Build the docker run command string ---
    DOCKER_CMD="docker run -d"
    DOCKER_CMD+=" --name \"$CONTAINER_NAME\"" # Using quotes for robustness
    DOCKER_CMD+=" --restart unless-stopped"

    # --- Environment Variables ---
    DOCKER_CMD+=" -e PUID=${PUID}"
    DOCKER_CMD+=" -e PGID=${PGID}"
    DOCKER_CMD+=" -e TZ=${TZ}"
    DOCKER_CMD+=" -e PASSWORD=\"${ACCESS_PASSWORD}\"" # Password needs quotes if it might contain spaces or special characters
    # DOCKER_CMD+=" -e SUDO_ACCESS=false" # Optional: uncomment to disable sudo

    # --- Port Mapping (Host:Container) ---
    DOCKER_CMD+=" -p ${WEBUI_HOST_PORT}:${WEBUI_CONTAINER_PORT}" # WebUI/noVNC as per command

    # --- Volume Mapping (Host:Container) ---
    # Only map the main config directory as per your working command
    DOCKER_CMD+=" -v \"$HOST_CONFIG_DIR\":\"$WEB_CONTAINER_CONFIG_DIR\"" # Config persistence

    # Removed Downloads volume mapping

    # --- Resource Limits (Recommended) ---
    DOCKER_CMD+=" --shm-size=\"1gb\"" # Shared memory size as per command
    # DOCKER_CMD+=" --memory=\"4g\"" # !! OPTIONAL: Set total memory limit (adjust as needed) !!

    # --- Add the Image Name ---
    DOCKER_CMD+=" ${WEB_IMAGE}"


    # --- Execute the command ---
    echo -e "${YELLOW}Executing Docker command:${NC}"
    echo "$DOCKER_CMD" # Print the command
    eval "$DOCKER_CMD" # Use eval to correctly handle quotes in paths

    # --- Check for errors ---
    # $? contains the exit status of the last executed command (eval "$DOCKER_CMD")
    if [ $? -ne 0 ]; then
        echo -e "${RED}✖ Error: Failed to start Webtop container.${NC}"
        echo -e "${RED}  The 'eval' command exited with status $?.${NC}" # Report the exact exit status
        echo -e "${RED}  Check Docker logs for more details if the container was partially created:${NC}"
        echo -e "  ${CYAN}docker logs $CONTAINER_NAME${NC}"
        # Exit the script with an error code
        exit 1
    fi
fi # End if container already exists check


# ───[ Post-Setup Information ]──────────────────────────────────
echo
echo -e "${GREEN}✅ Webtop container '$CONTAINER_NAME' started successfully!${NC}"
echo
echo -e "${BOLD}📍 Key Information:${NC}"
echo -e "- Container Name: ${CYAN}$CONTAINER_NAME${NC}"
echo -e "- Webtop Image: ${CYAN}${WEB_IMAGE}${NC} ('latest' tag -> Alpine XFCE)"
echo -e "- Host IP detected: ${CYAN}${HOST_IP}${NC}"
echo -e "- PUID/PGID used: ${CYAN}${PUID}/${PGID}${NC} (Hardcoded from command)"
echo -e "- Timezone set to: ${CYAN}${TZ}${NC} (Hardcoded from command)"
echo -e "- Shared memory size: ${CYAN}1gb${NC}"

echo
echo -e "${BOLD}📡 Networking Notes:${NC}"
echo -e "- Web UI (noVNC) port mapped: ${CYAN}${WEBUI_HOST_PORT} (Host) -> ${WEBUI_CONTAINER_PORT} (Container)${NC}"
echo -e "- Direct VNC port (${CYAN}3001${NC} in container) is ${RED}not mapped${NC} to the host as per the provided command."
echo -e "- If accessing from outside your LAN, ensure your ${BOLD}host machine's firewall${NC} allows port ${WEBUI_HOST_PORT}."
echo -e "- Port forwarding on your router would need to point to ${BOLD}your host machine's IP${NC} (${HOST_IP}) for port ${WEBUI_HOST_PORT}."
echo -e "${BOLD}Note:${NC} If accessing from the host machine, you can also use ${YELLOW}http://localhost:${WEBUI_HOST_PORT}${NC} or ${YELLOW}http://127.0.0.1:${WEBUI_HOST_PORT}${NC} for the UI."

echo
echo -e "${BOLD}🛠 Common Docker Commands:${NC}"
echo -e "  ${CYAN}docker stop|start|restart $CONTAINER_NAME${NC} - Stop|Start|Restart the container"
echo -e "  ${CYAN}docker logs -f $CONTAINER_NAME${NC}           - View live container logs"
echo -e "  ${CYAN}docker ps -a${NC}                          - Check if container is running (look for '$CONTAINER_NAME')"
echo -e "  ${CYAN}docker rm -f $CONTAINER_NAME${NC}          - Force remove container (config/data ${BOLD}preserved${NC} in host paths!)"
echo -e "  ${CYAN}docker exec -it $CONTAINER_NAME bash${NC}    - Enter container shell (or 'sh' if bash is not default)"

echo
echo -e "${BOLD}📂 Mounted Host Directory (for Persistence & File Transfer):${NC}" # Updated heading
echo -e "  Host Config: ${CYAN}$HOST_CONFIG_DIR${NC}         -> Container: ${YELLOW}$WEB_CONTAINER_CONFIG_DIR${NC}"
echo -e "${BOLD}Note:${NC} The Downloads folder inside the container is located within the mounted config directory (e.g., ${YELLOW}$WEB_CONTAINER_CONFIG_DIR/home/abc/Downloads${NC}). You can access it on your host at ${CYAN}$HOST_CONFIG_DIR/home/abc/Downloads${NC} after the container has initialized and created the 'abc' user's home structure.${NC}" # Updated Downloads access info

echo
echo -e "${BOLD}🚀 First Time Access & Interaction Tips:${NC}"
echo -e "- 🌐 Go to the Webtop desktop in your browser: ${YELLOW}http://${HOST_IP}:${WEBUI_HOST_PORT}${NC}"
echo -e "- 🔑 You will be prompted for a password. Use the secure password you entered when running this script."
echo -e "- 🖥️ Explore the XFCE desktop environment!"
echo -e "- 📁 ${UNDERLINE}Accessing Shared Files:${NC} Files you put in the host directory ${CYAN}$HOST_CONFIG_DIR/home/abc/Downloads${NC} will appear inside the container at ${YELLOW}$WEB_CONTAINER_CONFIG_DIR/home/abc/Downloads${NC} (which is typically the standard 'Downloads' folder in the user's home directory). You can also place files directly into other subfolders of ${CYAN}$HOST_CONFIG_DIR${NC} (like ${CYAN}$HOST_CONFIG_DIR/home/abc${NC}) to access them in the container. Use the file manager inside Webtop to access them." # Updated Downloads access tip
echo -e "- 📦 ${UNDERLINE}Installing Software:${NC} Open the Terminal Emulator within the Webtop desktop. Since this is Alpine-based (via the 'latest' tag), you'll likely use ${CYAN}sudo apk update${NC} followed by ${CYAN}sudo apk add <package_name>${NC} to add applications. (Note: Alpine uses apk, not apt)."
echo -e "- ⌨️ ${UNDERLINE}Copy/Paste & Input:${NC} Most noVNC clients have a sidebar or top bar toolbar. Look for icons for clipboard (copy/paste text between your host and the container), file transfer (often slow, volume mounts are better), sending special keys (like Ctrl+Alt+Del), and fullscreen mode."
echo -e "- 🖼️ ${UNDERLINE}Performance:${NC} Performance depends on your server's CPU (for rendering the desktop/apps and VNC encoding) and your network connection quality. You are streaming video of the desktop."
echo -e "- 🚪 ${UNDERLINE}Logging Out/Disconnecting:${NC} Simply closing the browser tab disconnects your VNC session, but the container and the desktop environment inside keep running. To stop the whole desktop session, you'd typically log out from the desktop environment's menu (like in a regular OS) or stop the container via docker stop $CONTAINER_NAME."
echo -e "- 🩺 ${UNDERLINE}Troubleshooting:${NC} If the web page doesn't load, use ${CYAN}docker logs $CONTAINER_NAME${NC} to check for errors during startup."

echo
echo -e "${GREEN}🚀 Webtop setup script finished.${NC}"
echo -e "${GREEN}  Access your Alpine XFCE Webtop at ${YELLOW}http://${HOST_IP}:${WEBUI_HOST_PORT}${NC}${NC}"
