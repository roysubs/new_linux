#!/bin/bash

RED='\e[0;31m'
YELLOW='\e[1;33m' # Added yellow for warnings/notes
NC='\033[0m'

# Check if docker is installed:
if [ -f "docker-setup-deb-variants.sh" ]; then "./docker-setup-deb-variants.sh"; fi

set -e # Exit immediately if a command exits with a non-zero status.

CONFIG_ROOT="$HOME/.config/media-stack"
ENV_FILE=".env"
BASE_MEDIA="/mnt/media" # This is the mount point, seen by containers as the root of media
DOCKER_COMPOSE_FILE="docker-compose-media-stack.yaml" # Updated Docker Compose filename

# Ensure mikefarah/yq is installed for yaml parsing
if ! command -v yq &>/dev/null || ! yq --version 2>&1 | grep -q "mikefarah/yq"; then
    echo "Installing mikefarah/yq..."
    YQ_ARCH=$(uname -m)
    case "${YQ_ARCH}" in
        x86_64) YQ_BINARY="yq_linux_amd64";;
        aarch64) YQ_BINARY="yq_linux_arm64";;
        *) echo "Unsupported arch: ${YQ_ARCH}"; exit 1;;
    esac
    sudo curl -L "https://github.com/mikefarah/yq/releases/latest/download/${YQ_BINARY}" -o /usr/local/bin/yq && sudo chmod +x /usr/local/bin/yq || { echo "Failed to install yq."; exit 1; }
    echo "yq installed."
else
    echo "mikefarah/yq already installed."
fi

echo "🔍 Parsing ${DOCKER_COMPOSE_FILE}..."

CONTAINER_NAMES=($(yq -r '.services | keys | .[]' "$DOCKER_COMPOSE_FILE"))
IMAGES=($(yq -r '.services.*.image' "$DOCKER_COMPOSE_FILE"))
PORTS=($(yq -r '.services.*.ports[]?' "$DOCKER_COMPOSE_FILE" | cut -d: -f1 | grep -E '^[0-9]+$' | sort -u))

if [ "${#CONTAINER_NAMES[@]}" -ne "${#IMAGES[@]}" ]; then
    echo "‼️ Warning: The number of extracted container names (${#CONTAINER_NAMES[@]}) does not match the number of images (${#IMAGES[@]}). Output might be misaligned." >&2
fi

echo
echo "Container names (with Image names) that will be used:"
for i in "${!CONTAINER_NAMES[@]}"; do
    name="${CONTAINER_NAMES[$i]}"
    image="${IMAGES[$i]:-N/A (Image not found)}"
    echo "- $name ($image)"
done

echo ""
echo "Ports that will be used:"
if [ "${#PORTS[@]}" -eq 0 ]; then
    echo "- No host ports exposed"
else
    for port in "${PORTS[@]}"; do
        echo "- $port"
    done
fi
echo ""

echo "🔎 Checking for existing containers that could conflict..."
container_conflict_found=false
for name in "${CONTAINER_NAMES[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -wq "$name"; then
        echo -e "❌ A container named \"$name\" already exists. Remove it with: ${YELLOW}docker rm -f $name${NC}"
        container_conflict_found=true
    fi
done
if [ "$container_conflict_found" = true ]; then
    echo "‼️ One or more container name conflicts were found. Please resolve them before proceeding."
    exit 1
fi
echo "✅ No conflicting container names found."

echo "🔎 Checking for running containers using images from this compose file..."
EXISTING_RUNNING_CONTAINERS=$(docker ps --format '{{.Names}} {{.Image}}')
CONFLICTING_IMAGES=()
FILTERED_IMAGES=()
for img in "${IMAGES[@]}"; do
    if [[ "$img" != "none" && "$img" != "" ]]; then
        FILTERED_IMAGES+=("$img")
    fi
done
if [ "${#FILTERED_IMAGES[@]}" -gt 0 ]; then
    for img in "${FILTERED_IMAGES[@]}"; do
        if echo "$EXISTING_RUNNING_CONTAINERS" | grep -Fw -- "$img" > /dev/null; then
            CONTAINERS_USING_IMAGE=$(echo "$EXISTING_RUNNING_CONTAINERS" | grep -Fw -- "$img" | awk '{print $1}')
            echo -e "⚠️  WARNING: Image \"$img\" is already used by running container(s): ${YELLOW}$CONTAINERS_USING_IMAGE${NC}"
            CONFLICTING_IMAGES+=("$img")
        fi
    done
fi
if [ "${#CONFLICTING_IMAGES[@]}" -gt 0 ]; then
    read -p "Continue anyway? (y/N): " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
fi
if [ "${#CONFLICTING_IMAGES[@]}" -eq 0 ]; then
    echo "✅ No running containers found using these images."
fi

echo "🔎 Checking for port conflicts..."
port_conflict_found=false
for port in "${PORTS[@]}"; do
    if ss -tuln | grep -q ":$port "; then
        echo -e "❌ Port $port is already in use. Please stop the service using it or change the docker-compose config."
        port_conflict_found=true
    fi
done
if [ "$port_conflict_found" = true ]; then
    echo "‼️ One or more port conflicts were found. Please resolve them before proceeding."
    exit 1
fi
echo "✅ No conflicting ports found."

echo "✅ All conflict checks passed. Proceeding with system checks and setup..."

if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing..."
    if curl -fsSL https://get.docker.com | sh; then
        sudo usermod -aG docker "$USER"
        echo "Docker installed successfully. Please log out and back in to apply group changes or run 'newgrp docker'."
        exit 1
    else
        echo "❌ Failed to install Docker."
        exit 1
    fi
else
    echo "Docker is already installed."
fi

if ! docker compose version &>/dev/null; then
    echo "Docker Compose plugin not found. Installing..."
    DOCKER_CONFIG_PATH=${DOCKER_CONFIG:-$HOME/.docker} # Renamed variable to avoid conflict
    mkdir -p "$DOCKER_CONFIG_PATH/cli-plugins" || { echo "❌ Failed to create Docker config directory."; exit 1; }
    LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$LATEST_COMPOSE_VERSION" ]; then # Fallback if API fails
        echo "Could not fetch latest Docker Compose version, using a recent default."
        LATEST_COMPOSE_VERSION="v2.27.1" # Or your preferred fixed version
    fi
    if curl -SL "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" \
      -o "$DOCKER_CONFIG_PATH/cli-plugins/docker-compose"; then
        chmod +x "$DOCKER_CONFIG_PATH/cli-plugins/docker-compose" || { echo "❌ Failed to set execute permissions on docker-compose plugin."; exit 1; }
        echo "Docker Compose plugin installed successfully."
    else
        echo "❌ Failed to download Docker Compose plugin."
        exit 1
    fi
fi

TZ=$(timedatectl show --value -p Timezone)
PUID=$(id -u)
PGID=$(id -g)
echo "Using UID=$PUID and GID=$PGID, TimeZone=$TZ"

echo "--- Media Directory Setup ---"
DEFAULT_SOURCE_PATH="/mnt/sdc1/Downloads" # Example: Changed default to avoid direct 'Downloads' in path
read -p "Enter path to your actual media location (e.g. /srv/mymedia, this will be bind-mounted to $BASE_MEDIA) [default: $DEFAULT_SOURCE_PATH]: " SOURCE_PATH_INPUT
SOURCE_PATH="${SOURCE_PATH_INPUT:-$DEFAULT_SOURCE_PATH}"
echo "Using source path for media: $SOURCE_PATH"

if [ ! -d "$SOURCE_PATH" ]; then
    echo "Source path \"$SOURCE_PATH\" does not exist. Creating..."
    sudo mkdir -p "$SOURCE_PATH" || { echo "❌ Error creating source path: $SOURCE_PATH"; exit 1; }
fi
if [ ! -d "$BASE_MEDIA" ]; then
    echo "Mount point $BASE_MEDIA does not exist. Creating..."
    sudo mkdir -p "$BASE_MEDIA" || { echo "❌ Error creating mount point: $BASE_MEDIA"; exit 1; }
fi

if mountpoint -q "$BASE_MEDIA"; then
    echo "$BASE_MEDIA is already mounted."
else
    echo "Mounting $SOURCE_PATH to $BASE_MEDIA..."
    if sudo mount --bind "$SOURCE_PATH" "$BASE_MEDIA"; then
        echo "Mounted $SOURCE_PATH to $BASE_MEDIA"
    else
        echo "❌ Error mounting $SOURCE_PATH to $BASE_MEDIA. Check permissions and if the source path exists."
        exit 1
    fi
fi

echo "Ensuring required media subdirectories exist under $SOURCE_PATH (visible at $BASE_MEDIA)..."
# Subdirectories for Radarr, Lidarr, downloads etc.
# These will be created inside $SOURCE_PATH and thus appear under $BASE_MEDIA after bind mount.
SUBDIRS=("$BASE_MEDIA/downloads" "$BASE_MEDIA/movies" "$BASE_MEDIA/tv" "$BASE_MEDIA/music" "$BASE_MEDIA/books" "$BASE_MEDIA/audiobooks")
for subdir in "${SUBDIRS[@]}"; do
    if sudo mkdir -p "$subdir"; then
        echo "Created/Ensured directory: $subdir"
    else
        echo "❌ Error creating necessary media subdirectory: $subdir."
        echo "Please check permissions for the user $USER (or root if using sudo) on $SOURCE_PATH."
        exit 1
    fi
done

echo "Creating necessary config directories under ${CONFIG_ROOT}..."
# Config dirs for qbittorrentvpn (which includes wireguard), radarr, lidarr, prowlarr
CONFIG_SUBDIRS=("${CONFIG_ROOT}/qbittorrentvpn/wireguard" "${CONFIG_ROOT}/radarr" "${CONFIG_ROOT}/lidarr" "${CONFIG_ROOT}/prowlarr" "${CONFIG_ROOT}/raradd" "${CONFIG_ROOT}/readarr" "${CONFIG_ROOT}/bazarr")
for conf_subdir in "${CONFIG_SUBDIRS[@]}"; do
    # Use -p for mkdir to create parent directories as needed
    mkdir -p "$conf_subdir" || { echo "❌ Error creating config directory: $conf_subdir"; exit 1; }
done
echo "✅ Config directories created."


echo "Setting ownership on $BASE_MEDIA to $PUID:$PGID..."
if ! sudo chown -R "$PUID:$PGID" "$BASE_MEDIA"; then
    echo "❌ Error setting ownership on $BASE_MEDIA. Make sure you have appropriate permissions."
    exit 1
fi

echo
echo "--- WireGuard VPN Configuration ---"
echo -e "The qBittorrent+VPN container (${YELLOW}dyonr/qbittorrentvpn${NC} in your compose file) requires a WireGuard configuration file."
echo -e "You need to obtain this WireGuard configuration file (usually ending in ${YELLOW}.conf${NC}) from your VPN provider."
echo -e "This typically involves:"
echo -e "  1. Logging into your VPN provider's website."
echo -e "  2. Navigating to a 'Manual Setup', 'Router Setup', or 'WireGuard Configuration' section."
echo -e "  3. Generating or downloading the ${YELLOW}.conf${NC} file."
echo

DEFAULT_CONFIG_FILE_PATH="$HOME/wg0.conf" # Example default path
WIREGUARD_SOURCE_CONFIG_FILE_PATH=""
while true; do
    read -p "Enter the FULL path to your WireGuard configuration file (e.g., /path/to/your/wg0.conf) [default: $DEFAULT_CONFIG_FILE_PATH]: " CONFIG_FILE_PATH_INPUT
    WIREGUARD_SOURCE_CONFIG_FILE_PATH="${CONFIG_FILE_PATH_INPUT:-$DEFAULT_CONFIG_FILE_PATH}"
    if [ -f "$WIREGUARD_SOURCE_CONFIG_FILE_PATH" ]; then
        echo "✅ WireGuard configuration file found at: $WIREGUARD_SOURCE_CONFIG_FILE_PATH"
        break
    else
        echo "❌ File not found at '$WIREGUARD_SOURCE_CONFIG_FILE_PATH'. Please enter a valid path."
    fi
done

# Define the target directory and filename for the qbittorrentvpn container
TARGET_WG_CONF_DIR="${CONFIG_ROOT}/qbittorrentvpn/wireguard"
TARGET_WG_CONF_FILE="${TARGET_WG_CONF_DIR}/wg0.conf" # Most containers expect wg0.conf

# Ensure the target directory exists (mkdir -p in config setup should have handled qbittorrentvpn/wireguard)
mkdir -p "$TARGET_WG_CONF_DIR" || { echo "❌ Error ensuring WireGuard target config directory exists: $TARGET_WG_CONF_DIR"; exit 1; }

cp "$WIREGUARD_SOURCE_CONFIG_FILE_PATH" "$TARGET_WG_CONF_FILE" || { echo "❌ Error copying WireGuard config file to $TARGET_WG_CONF_FILE"; exit 1; }
echo "✅ WireGuard configuration file copied to $TARGET_WG_CONF_FILE"
echo "This file will be used by the qbittorrentvpn container."

echo
echo "Creating .env file..."
env_content=""
env_content+="TZ=$TZ"$'\n'
env_content+="PUID=$PUID"$'\n'
env_content+="PGID=$PGID"$'\n'
env_content+="CONFIG_ROOT=${CONFIG_ROOT}"$'\n' # Ensures compose file can use this
# Add any other global environment variables if needed by multiple services in compose
echo "$env_content" > "$ENV_FILE"
echo ".env file created with the following content:"
cat "$ENV_FILE"
echo

echo "Launching the Docker stack with 'docker compose up -d'..."
if docker compose -f "$DOCKER_COMPOSE_FILE" --env-file "$ENV_FILE" up -d; then
    echo "✅ Docker stack launched successfully!"
else
    echo "❌ Failed to launch Docker stack."
    exit 1
fi

echo
echo "✅ Media stack setup complete!"
echo
echo "To manage individual services (e.g., radarr):"
echo -e "  Stop:    ${YELLOW}docker compose stop radarr${NC}"
echo -e "  Start:   ${YELLOW}docker compose up -d radarr${NC}"
echo -e "  Restart: ${YELLOW}docker compose restart radarr${NC}"
echo -e "  Logs:    ${YELLOW}docker compose logs radarr${NC}"
echo
echo "qbittorrentvpn WebUI has username 'admin' and password 'adminadmin' by default."
echo "I normally set the other media components to the same for convenience."
echo
# Existing line:
# echo "✅ Media stack setup complete!"
# echo # Existing blank line

# --- BEGIN ADDITION ---
echo
echo "--- Application Access URLs ---"
echo "The following services should be accessible at these URLs:"
echo "(Note: If accessing from another device on your network, replace 'localhost' with this machine's IP address)"

# The CONTAINER_NAMES array is already populated earlier in the script.
# The DOCKER_COMPOSE_FILE variable is also set.
for service_name in "${CONTAINER_NAMES[@]}"; do
    # Query for the first port mapping for the current service.
    # yq's '.services.<service_name>.ports[0]?' attempts to get the first port definition.
    # The '?' ensures it returns 'null' (as a string) if 'ports' is missing or empty, instead of erroring.
    port_mapping=$(yq -r ".services.\"$service_name\".ports[0]?" "$DOCKER_COMPOSE_FILE")

    # Check if port_mapping is not empty and not the literal string "null"
    if [ -n "$port_mapping" ] && [ "$port_mapping" != "null" ]; then
        # Extract the host port (the part before the first colon)
        host_port=$(echo "$port_mapping" | cut -d: -f1)

        # Ensure host_port is a valid number.
        # This also filters out cases where port_mapping might be more complex than "HOST:CONTAINER"
        # or if cut -d: -f1 results in a non-numeric string.
        if [[ "$host_port" =~ ^[0-9]+$ ]]; then
            # Capitalize the first letter of the service name for prettier display
            display_name="$(tr '[:lower:]' '[:upper:]' <<< ${service_name:0:1})${service_name:1}"
            echo "- ${display_name}: http://$(hostname -I | awk '{print $1}'):${host_port}"
        fi
    fi
done
echo # Add a blank line for spacing before the next section
# --- END ADDITION ---

# Existing lines:
# echo "To manage individual services (e.g., radarr):"
# ...
