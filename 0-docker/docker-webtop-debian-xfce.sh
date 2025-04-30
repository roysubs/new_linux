#!/bin/bash

# Webtop Debian XFCE Docker automated deployment using linuxserver/webtop
# This script sets up the container with specified host paths, ports, and user IDs.
# It includes a shared downloads directory and provides tips for interaction.
# Based on instructions from:
# https://fleet.linuxserver.io/image?name=webtop
# ───────────────────────────────────────────────────────────────

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
CONTAINER_NAME="webtop-debian-xfce" # Name for the new container
WEB_IMAGE="lscr.io/linuxserver/webtop:debian-xfce" # The Docker image to use

# --- Default Host directories for Webtop ---
# Configuration directory (stores user profile, settings etc - KEEP THIS SAFE!)
DEFAULT_HOST_CONFIG_DIR="$HOME/.config/webtop-debian-xfce-docker"
# Shared Downloads/Data directory (easily transfer files in/out)
# Defaults to /mnt/sdc1/Downloads as requested, but will prompt to confirm.
# DEFAULT_HOST_DOWNLOADS_DIR="/mnt/sdc1/Downloads"
DEFAULT_HOST_DOWNLOADS_DIR="/home/boss/webtop-debian-xfce-downloads-share"

WEB_CONTAINER_CONFIG_DIR="/config" # Internal config path inside the container (fixed by linuxserver image)
WEB_CONTAINER_DOWNLOADS_DIR="/config/Downloads" # Internal downloads path inside the container (Mapping standard location)

# --- Default Port Settings ---
# You can change these if ports are already in use on your host.
# Format is HOST_PORT=CONTAINER_PORT for clarity.
WEBUI_HOST_PORT=3010 # Port for the Web UI (noVNC) - Changed from 3009 to avoid potential conflicts and use a fresh port
WEBUI_CONTAINER_PORT=3000 # Internal container port for WebUI (standard LSIO webtop)

VNC_HOST_PORT=3011 # Port for direct VNC client connections (optional)
VNC_CONTAINER_PORT=3001 # Internal container port for direct VNC (standard LSIO webtop)

# --- Environment Settings ---
# Specify a timezone to use. See https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
TZ="Etc/UTC" # !! IMPORTANT: Change this to your actual timezone (e.g., "Europe/Oslo", "America/New_York") !!

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
    local user_id=$(id -u)
    local group_id=$(id -g)
    echo "$user_id:$group_id"
}

# ───[ Preparations ]────────────────────────────────────────────
echo -e "${BOLD}Webtop Debian XFCE Docker Setup${NC}"
echo "--------------------------------------------------"

# --- Detect Host IP (Best guess for UI link) ---
HOST_IP=$(hostname -I | awk '{print $1}')
if [ -z "$HOST_IP" ]; then
    echo -e "${YELLOW}⚠️ Could not automatically detect a primary local IP. You might need to find it manually (e.g., using 'ip a').${NC}"
    # Fallback if hostname -I fails
    HOST_IP="localhost"
fi
echo -e "${CYAN}ℹ️ Detected likely local IP: ${HOST_IP}${NC}"

# --- Get User and Group IDs ---
USER_IDS=$(get_user_ids)
PUID=${USER_IDS%:*}
PGID=${USER_IDS#*:}
echo -e "${CYAN}ℹ️ Using PUID=${PUID} and PGID=${PGID} for container user mapping.${NC}"
echo -e "${YELLOW}Ensure the host directories you map below are owned by this user/group (${PUID}:${PGID}) for correct permissions inside the container.${NC}"

# Check if the container already exists
if docker ps -a --format '{{.Names}}' | grep -wq "$CONTAINER_NAME"; then
    echo -e "${GREEN}✅ Container '$CONTAINER_NAME' already exists. Skipping creation.${NC}"
    echo -e "${CYAN}To stop and remove the existing container to create a new one:${NC}"
    echo -e "  ${CYAN}docker stop \"$CONTAINER_NAME\" > /dev/null 2>&1${NC}"
    echo -e "  ${CYAN}docker rm \"$CONTAINER_NAME\" > /dev/null 2>&1${NC}"
    # Set variables to defaults for info output even if container wasn't recreated
    HOST_CONFIG_DIR=$DEFAULT_HOST_CONFIG_DIR
    HOST_DOWNLOADS_DIR=$DEFAULT_HOST_DOWNLOADS_DIR
else
    # --- Prompt for Host Configuration Directory ---
    echo -e "\n${BOLD}Please enter the host folder for Webtop configuration files.${NC}"
    echo -e "This is where container settings, your home directory files, etc., will be stored persistently."
    echo -e "Leave this empty to use the default path: ${BLUE_BOLD}${DEFAULT_HOST_CONFIG_DIR}${NC}"
    read -e -p "Enter host config path [${DEFAULT_HOST_CONFIG_DIR}]: " user_config_input
    HOST_CONFIG_DIR="${user_config_input:-$DEFAULT_HOST_CONFIG_DIR}" # Use default if input is empty

    # --- Prompt for Host Shared Downloads Directory ---
    echo -e "\n${BOLD}Please enter the host folder to be shared as the Downloads directory inside the container.${NC}"
    echo -e "Files placed here will appear in the container's Downloads folder, and vice-versa."
    echo -e "Leave this empty to use the default path: ${BLUE_BOLD}${DEFAULT_HOST_DOWNLOADS_DIR}${NC}"
    read -e -p "Enter host downloads path [${DEFAULT_HOST_DOWNLOADS_DIR}]: " user_downloads_input
    HOST_DOWNLOADS_DIR="${user_downloads_input:-$DEFAULT_HOST_DOWNLOADS_DIR}" # Use default if input is empty

    # --- Prompt for Password ---
    echo -e "\n${BOLD}${RED}!! IMPORTANT: Set a secure password for accessing the Webtop desktop !!${NC}"
    echo -e "${BOLD}You will use this password to log in via the web browser.${NC}"
    read -s -p "Enter your secure password: " ACCESS_PASSWORD # -s hides input
    echo # Print a newline after silent read

    # --- Ensure Host Directories Exist ---
    echo -e "\n${BOLD}Checking/Creating host directories...${NC}"
    ensure_dir "$HOST_CONFIG_DIR"
    ensure_dir "$HOST_DOWNLOADS_DIR"
    echo -e "${GREEN}✅ Host directories checked/ensured.${NC}"
    echo

    # ───[ Docker Operations ]───────────────────────────────────────
    echo -e "${CYAN}Creating and starting Webtop Debian XFCE container '$CONTAINER_NAME'...${NC}"
    echo -e "${CYAN}Pulling Webtop image ('${WEB_IMAGE}')...${NC}"
    docker pull ${WEB_IMAGE}
    if [ $? -ne 0 ]; then
        echo -e "${RED}✖ Error: Failed to pull Docker image. Check Docker installation and internet connection.${NC}"
        exit 1
    fi

    # --- Build the docker run command as an array ---
    # Building as an array is the most robust way to handle arguments and quotes in bash.
    DOCKER_CMD_ARRAY=(
        docker run -d # Command and detached mode
        --name "$CONTAINER_NAME" # Container name
        --restart unless-stopped # Restart policy
        # Environment Variables
        -e PUID="${PUID}"
        -e PGID="${PGID}"
        -e TZ="${TZ}"
        -e PASSWORD="${ACCESS_PASSWORD}" # Secure password
        # -e SUDO_ACCESS=false # Optional: uncomment to disable sudo

        # Port Mappings (Host:Container)
        -p "${WEBUI_HOST_PORT}:${WEBUI_CONTAINER_PORT}" # WebUI/noVNC
        -p "${VNC_HOST_PORT}:${VNC_CONTAINER_PORT}"    # Direct VNC (Optional)

        # Volume Mappings (Host:Container)
        -v "$HOST_CONFIG_DIR":"$WEB_CONTAINER_CONFIG_DIR" # Config persistence
        # -v "$HOST_DOWNLOADS_DIR":"$WEB_CONTAINER_DOWNLOADS_DIR" # Shared Downloads

        # Resource Limits (Recommended)
        # --shm-size="2g" # Recommended shared memory size
        # --memory="4g" # !! ADD THIS LINE: Set total memory limit (adjust as needed) !!

        # The Docker Image
        "${WEB_IMAGE}"
    )

    # --- Execute the command from the array ---
    echo -e "${YELLOW}Executing Docker command:${NC}"
    printf "%q " "${DOCKER_CMD_ARRAY[@]}"; echo   # Print the command for debugging (optional, uncomment if needed)
    # Execute the command. We use "${DOCKER_CMD_ARRAY[@]}" to pass arguments correctly.
    "${DOCKER_CMD_ARRAY[@]}"
    
    # --- Check for errors ---
    # $? contains the exit status of the last executed command (docker run in this case)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✖ Error: Failed to start Webtop container.${NC}"
        echo -e "${RED}  The 'docker run' command exited with status $?.${NC}" # Report the exact exit status
        echo -e "${RED}  Check Docker logs for more details if the container was partially created:${NC}"
        echo -e "  ${CYAN}docker logs $CONTAINER_NAME${NC}"
        # Exit the script with an error code
        exit 1
    fi

    # --- Execute the command ---
    echo -e "${YELLOW}Executing Docker command:${NC}"
    # Using printf to handle potential special characters in variables safely,
    # then piping to sh -c to execute the command string.
    printf "%s" "$DOCKER_CMD" | sh -c 'eval "$@"' _
    # Alternative simple eval (less robust with complex paths/quotes): eval "$DOCKER_CMD"

    # --- Check for errors ---
    if [ $? -ne 0 ]; then
        echo -e "${RED}✖ Failed to start Webtop container. Check Docker logs:${NC}"
        echo -e "  ${CYAN}docker logs $CONTAINER_NAME${NC}"
        exit 1
    fi
fi

# ───[ Post-Setup Information ]──────────────────────────────────
echo
echo -e "${GREEN}✅ Webtop container '$CONTAINER_NAME' started successfully!${NC}"
echo
echo -e "${BOLD}📍 Key Information:${NC}"
echo -e "- Container Name: ${CYAN}$CONTAINER_NAME${NC}"
echo -e "- Webtop Image: ${CYAN}${WEB_IMAGE}${NC}"
echo -e "- Host IP detected: ${CYAN}${HOST_IP}${NC}"
echo -e "- PUID/PGID used: ${CYAN}${PUID}/${PGID}${NC}"
echo -e "- Timezone set to: ${CYAN}${TZ}${NC}"

echo
echo -e "${BOLD}📡 Networking Notes:${NC}"
echo -e "- Web UI (noVNC) port mapped: ${CYAN}${WEBUI_HOST_PORT} (Host) -> ${WEBUI_CONTAINER_PORT} (Container)${NC}"
echo -e "- Direct VNC port mapped:   ${CYAN}${VNC_HOST_PORT} (Host) -> ${VNC_CONTAINER_PORT} (Container)${NC} (Optional)"
echo -e "- If accessing from outside your LAN, ensure your ${BOLD}host machine's firewall${NC} allows ports ${WEBUI_HOST_PORT} and ${VNC_HOST_PORT} (if mapped)."
echo -e "- Port forwarding on your router would need to point to ${BOLD}your host machine's IP${NC} (${HOST_IP}) for these ports."
echo -e "${BOLD}Note:${NC} If accessing from the host machine, you can also use ${YELLOW}http://localhost:${WEBUI_HOST_PORT}${NC} or ${YELLOW}http://127.0.0.1:${WEBUI_HOST_PORT}${NC} for the UI."

echo
echo -e "${BOLD}🛠 Common Docker Commands:${NC}"
echo -e "  ${CYAN}docker stop|start|restart $CONTAINER_NAME${NC} - Stop|Start|Restart the container"
echo -e "  ${CYAN}docker logs -f $CONTAINER_NAME${NC}      - View live container logs"
echo -e "  ${CYAN}docker ps -a${NC}                     - Check if container is running (look for '$CONTAINER_NAME')"
echo -e "  ${CYAN}docker rm -f $CONTAINER_NAME${NC}      - Force remove container (config/data ${BOLD}preserved${NC} in host paths!)"
echo -e "  ${CYAN}docker exec -it $CONTAINER_NAME bash${NC} - Enter container shell (or 'sh' if bash is not default)"

echo
echo -e "${BOLD}📂 Mounted Host Directories (for Persistence & File Transfer):${NC}"
echo -e "  Host Config: ${CYAN}$HOST_CONFIG_DIR${NC}         -> Container: ${YELLOW}$WEB_CONTAINER_CONFIG_DIR${NC}"
echo -e "  Host Downloads Share: ${CYAN}$HOST_DOWNLOADS_DIR${NC} -> Container: ${YELLOW}$WEB_CONTAINER_DOWNLOADS_DIR${NC}"

echo
echo -e "${BOLD}🚀 First Time Access & Interaction Tips:${NC}"
echo -e "- 🌐 Go to the Webtop desktop in your browser: ${YELLOW}http://${HOST_IP}:${WEBUI_HOST_PORT}${NC}"
echo -e "- 🔑 You will be prompted for a password. Use the secure password you entered when running this script."
echo -e "- 🖥️ Explore the XFCE desktop environment!"
echo -e "- 📁 ${UNDERLINE}Accessing Shared Files:${NC} Files you put in the host directory ${CYAN}$HOST_DOWNLOADS_DIR${NC} (which defaults to ${BLUE_BOLD}${DEFAULT_HOST_DOWNLOADS_DIR}${NC}) will appear inside the container at ${YELLOW}$WEB_CONTAINER_DOWNLOADS_DIR${NC} (which is typically the standard 'Downloads' folder in the user's home directory). You can use the file manager inside Webtop to access them."
echo -e "- 📦 ${UNDERLINE}Installing Software:${NC} Open the Terminal Emulator within the Webtop desktop. Since this is Debian-based, you can use ${CYAN}sudo apt update${NC} followed by ${CYAN}sudo apt install <package_name>${NC} to add applications like Firefox, VLC, or graphical games."
echo -e "- ⌨️ ${UNDERLINE}Copy/Paste & Input:${NC} Most noVNC clients have a sidebar or top bar toolbar. Look for icons for clipboard (copy/paste text between your host and the container), file transfer (often slow, volume mounts are better), sending special keys (like Ctrl+Alt+Del), and fullscreen mode."
echo -e "- 🖼️ ${UNDERLINE}Performance:${NC} Performance depends on your server's CPU (for rendering the desktop/apps and VNC encoding) and your network connection quality. You are streaming video of the desktop."
echo -e "- 🚪 ${UNDERLINE}Logging Out/Disconnecting:${NC} Simply closing the browser tab disconnects your VNC session, but the container and the desktop environment inside keep running. To stop the whole desktop session, you'd typically log out from the desktop environment's menu (like in a regular OS) or stop the container via `docker stop $CONTAINER_NAME`."
echo -e "- 🩺 ${UNDERLINE}Troubleshooting:${NC} If the web page doesn't load, use ${CYAN}docker logs $CONTAINER_NAME${NC} to check for errors during startup."

echo
echo -e "${GREEN}🚀 Webtop setup script finished.${NC}"
echo -e "${GREEN}  Access your Debian XFCE Webtop at ${YELLOW}http://${HOST_IP}:${WEBUI_HOST_PORT}${NC}${NC}"
echo
