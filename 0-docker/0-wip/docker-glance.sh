#!/bin/bash

# Glance Dashboard Setup in Docker (for Linux) automated deployment.
# ────────────────────────────────────────────────

# Check if Docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker is not installed. Please install Docker and rerun."
    echo "See instructions: https://docs.docker.com/engine/install/"
    exit 1
fi

# ──[ Styling ]────────────────────────────────────
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BLUE_BOLD='\033[1;34m' # Used for default paths
BOLD='\033[1m'
NC='\033[0m' # No Color
UNDERLINE='\033[4m'

# ──[ Detect Host IP ]─────────────────────────────
HOST_IP_DETECTED=$(hostname -I | awk '{print $1}')
if [ -z "$HOST_IP_DETECTED" ]; then
    echo -e "${YELLOW}⚠️ Could not automatically detect a primary local IP. You might need to find it manually (e.g., using 'ip a').${NC}"
    DISPLAY_HOST_IP="localhost"
else
    DISPLAY_HOST_IP="$HOST_IP_DETECTED"
fi
echo -e "${CYAN}Detected local IP for access instructions: ${DISPLAY_HOST_IP}${NC}"


# ──[ Configuration ]──────────────────────────────
CONTAINER_NAME="glance"
APP_IMAGE="glanceapp/glance:latest"
DEFAULT_HOST_CONFIG_DIR="$HOME/.config/glance-docker"
APP_CONTAINER_CONFIG_DIR="/app/config"
DEFAULT_APP_HOST_PORT=8080
APP_CONTAINER_PORT=8080

# ──[ Helper Functions ]─────────────────────────
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

# ──[ Check for Existing Container ]───────────────
EXISTS=$(docker ps -a --format '{{.Names}}' | grep -w "$CONTAINER_NAME")
if [ ! -z "$EXISTS" ]; then
    echo -e "${YELLOW}An existing Glance container named '$CONTAINER_NAME' was found.${NC}"
    read -p "Do you want to remove it to proceed with a fresh installation? (y/N): " remove_existing
    if [[ "$remove_existing" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Stopping and removing existing container '$CONTAINER_NAME'...${NC}"
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1
        EXISTS=""
        echo -e "${GREEN}✅ Existing container removed.${NC}"
    else
        echo -e "${RED}✖ Installation aborted.${NC}"
        # ... (info about existing container can be added here if needed) ...
        exit 1
    fi
fi

echo
echo -e "${BOLD}Glance container '$CONTAINER_NAME' will be installed.${NC}"

echo -e "\n${BOLD}Please enter the host folder for Glance configuration files (e.g., glance.yml).${NC}"
read -e -p "Enter Glance config path [${DEFAULT_HOST_CONFIG_DIR}]: " user_config_input
HOST_CONFIG_DIR="${user_config_input:-$DEFAULT_HOST_CONFIG_DIR}"
ensure_dir "$HOST_CONFIG_DIR"
echo -e "${GREEN}✅ Host config directory for Glance: $HOST_CONFIG_DIR${NC}"
echo

echo -e "\n${BOLD}Please enter the host port for Glance Web UI.${NC}"
read -e -p "Enter Host Port for Glance [${DEFAULT_APP_HOST_PORT}]: " user_host_port_input
SELECTED_HOST_PORT="${user_host_port_input:-$DEFAULT_APP_HOST_PORT}"
echo -e "${GREEN}✅ Glance will be accessible on host port: $SELECTED_HOST_PORT${NC}"
echo

# ──[ Download Example Config if Necessary (Revised) ]─────────
if [ ! -f "$HOST_CONFIG_DIR/glance.yml" ] || [ ! -f "$HOST_CONFIG_DIR/home.yml" ]; then
    echo -e "${CYAN}Glance example config files (glance.yml/home.yml) not found in $HOST_CONFIG_DIR.${NC}"
    echo -e "${CYAN}Attempting to download example configuration files...${NC}"
    CONFIG_TARBALL_URL="https://github.com/glanceapp/docker-compose-template/archive/refs/heads/main.tar.gz"
    TEMP_ARCHIVE_EXTRACT_DIR=$(mktemp -d)
    DOWNLOAD_SUCCESSFUL=false

    echo -e "${CYAN}Downloading and extracting to temporary location: $TEMP_ARCHIVE_EXTRACT_DIR ${NC}"
    if curl -sL "$CONFIG_TARBALL_URL" | tar -xzf - -C "$TEMP_ARCHIVE_EXTRACT_DIR"; then
        GLANCE_YML_SOURCE_PATH="$TEMP_ARCHIVE_EXTRACT_DIR/docker-compose-template-main/config/glance.yml"
        HOME_YML_SOURCE_PATH="$TEMP_ARCHIVE_EXTRACT_DIR/docker-compose-template-main/config/home.yml"

        COPIED_GLANCE_YML=false
        COPIED_HOME_YML=false

        if [ -f "$GLANCE_YML_SOURCE_PATH" ]; then
            if cp "$GLANCE_YML_SOURCE_PATH" "$HOST_CONFIG_DIR/glance.yml"; then
                echo -e "${GREEN}✅ Copied example glance.yml to $HOST_CONFIG_DIR/glance.yml${NC}"
                COPIED_GLANCE_YML=true
            else
                echo -e "${RED}✖ Failed to copy glance.yml from temp directory.${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️ glance.yml not found in expected path in downloaded archive: $GLANCE_YML_SOURCE_PATH ${NC}"
        fi

        if [ -f "$HOME_YML_SOURCE_PATH" ]; then
            if cp "$HOME_YML_SOURCE_PATH" "$HOST_CONFIG_DIR/home.yml"; then
                echo -e "${GREEN}✅ Copied example home.yml to $HOST_CONFIG_DIR/home.yml${NC}"
                COPIED_HOME_YML=true
            else
                echo -e "${RED}✖ Failed to copy home.yml from temp directory.${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️ home.yml not found in expected path in downloaded archive: $HOME_YML_SOURCE_PATH ${NC}"
        fi
        
        if $COPIED_GLANCE_YML && $COPIED_HOME_YML; then
            DOWNLOAD_SUCCESSFUL=true
            echo -e "${CYAN}Please review and customize these example configuration files as needed.${NC}"
            echo -e "${CYAN}See Glance documentation: https://glanceapp.github.io/glance/configuration/ ${NC}"
        elif $COPIED_GLANCE_YML || $COPIED_HOME_YML; then # At least one file was copied
            echo -e "${YELLOW}Partially downloaded example configuration. Please check $HOST_CONFIG_DIR and complete manually.${NC}"
        else
            echo -e "${RED}✖ Failed to obtain necessary example configuration files automatically from archive.${NC}"
        fi
    else
        echo -e "${RED}✖ Failed to download or extract the main configuration archive.${NC}"
    fi
    rm -rf "$TEMP_ARCHIVE_EXTRACT_DIR" # Clean up temp directory

    if ! $DOWNLOAD_SUCCESSFUL ; then
        echo -e "${YELLOW}Manual configuration needed: Ensure glance.yml and home.yml (or other page configs) are in $HOST_CONFIG_DIR.${NC}"
        echo -e "${YELLOW}Refer to Glance documentation for examples: https://glanceapp.github.io/glance/configuration/ ${NC}"
    fi
else
    echo -e "${GREEN}✅ Existing glance.yml and home.yml found in $HOST_CONFIG_DIR. Skipping example download.${NC}"
fi
echo

# ... (rest of the script: pull image, run container, post-setup info - remains largely the same)
# Make sure to use SELECTED_HOST_PORT and HOST_CONFIG_DIR in the DOCKER_CMD and Post-Setup Info

echo -e "${CYAN}Pulling Glance image ('${APP_IMAGE}')...${NC}"
docker pull ${APP_IMAGE}
if [ $? -ne 0 ]; then
    echo -e "${RED}✖ Failed to pull Glance image. Check Docker and internet.${NC}"
    exit 1
fi

echo -e "${CYAN}Creating and starting Glance container...${NC}"
DOCKER_CMD="docker run -d"
DOCKER_CMD+=" -p ${SELECTED_HOST_PORT}:${APP_CONTAINER_PORT}"
DOCKER_CMD+=" --name $CONTAINER_NAME"
DOCKER_CMD+=" --restart unless-stopped"
DOCKER_CMD+=" -v \"$HOST_CONFIG_DIR\":\"$APP_CONTAINER_CONFIG_DIR\":ro"
DOCKER_CMD+=" ${APP_IMAGE}"

echo -e "${YELLOW}Executing Docker command:${NC}"
echo "$DOCKER_CMD"
eval "$DOCKER_CMD"

if [ $? -ne 0 ]; then
    echo -e "${RED}✖ Failed to start Glance container. Check Docker logs (${CYAN}docker logs $CONTAINER_NAME${RED}).${NC}"
    echo -e "${YELLOW}   Common issues: Chosen host port ${SELECTED_HOST_PORT} might be in use, or permission problems on '$HOST_CONFIG_DIR'.${NC}"
    echo -e "${YELLOW}   The Glance container runs as user 1000:1000. Ensure '$HOST_CONFIG_DIR' and its files are readable by this user.${NC}"
    echo -e "${YELLOW}   Example to fix permissions: sudo chown -R 1000:1000 \"$HOST_CONFIG_DIR\"${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Glance container '$CONTAINER_NAME' started successfully!${NC}"

echo
echo -e "${BOLD}📍 Glance Container Info:${NC}"
echo -e "- Container name: ${CYAN}$CONTAINER_NAME${NC}"
echo -e "- Host directory for config: ${CYAN}$HOST_CONFIG_DIR${NC}"
echo -e "  (Mapped to ${YELLOW}$APP_CONTAINER_CONFIG_DIR${NC} inside container, mounted read-only)"
echo -e "- Glance Web UI (HTTP): Port ${CYAN}${SELECTED_HOST_PORT}${NC}"
echo
echo -e "${BOLD}🔧 Configuration:${NC}"
echo -e "Glance is configured using YAML files (e.g., ${UNDERLINE}glance.yml${NC}, ${UNDERLINE}home.yml${NC}) located in:"
echo -e "  ${CYAN}$HOST_CONFIG_DIR${NC}"
echo -e "Refer to Glance docs: ${YELLOW}https://glanceapp.github.io/glance/configuration/${NC}"
echo
echo -e "${BOLD}🌐 Access Glance Web UI:${NC}"
echo -e "  Open your browser: ${YELLOW}http://${DISPLAY_HOST_IP}:${SELECTED_HOST_PORT}${NC}"
echo
echo -e "${BOLD}⚙️ Common Docker Commands:${NC}"
echo -e "  ${CYAN}docker start|stop|restart $CONTAINER_NAME${NC}"
echo -e "  ${CYAN}docker logs -f $CONTAINER_NAME${NC}"
echo -e "  ${CYAN}docker rm $CONTAINER_NAME${NC} (config in ${HOST_CONFIG_DIR} is preserved)"
echo
echo -e "${BOLD}🚀 Next Steps:${NC}"
echo -e "  1. Customize ${CYAN}$HOST_CONFIG_DIR/glance.yml${NC} and ${CYAN}$HOST_CONFIG_DIR/home.yml${NC}."
echo -e "  2. Restart Glance (${CYAN}docker restart $CONTAINER_NAME${NC}) after changing ${CYAN}glance.yml${NC}."
echo

exit 0
