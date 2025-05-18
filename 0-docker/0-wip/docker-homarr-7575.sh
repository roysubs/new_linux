#!/bin/bash

# Homarr Setup in Docker (for Linux) automated deployment.
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
HOST_IP=$(hostname -I | awk '{print $1}')
if [ -z "$HOST_IP" ]; then
    echo -e "${YELLOW}⚠️ Could not automatically detect a primary local IP. You might need to find it manually (e.g., using 'ip a').${NC}"
    HOST_IP="localhost" # Fallback
fi
echo -e "${CYAN}Detected local IP: ${HOST_IP}${NC}"


# ──[ Configuration ]──────────────────────────────
CONTAINER_NAME="homarr"
HOMARR_IMAGE="ghcr.io/homarr-labs/homarr:latest"
# The N36L Microserver AMD Athlon(tm) II Neo N36L Dual-Core Processor, looking at lscpu, it supports CPU instruction sets up to sse4a and abm,
# but it notably lacks AVX (Advanced Vector Extensions) and its newer variants (AVX2, AVX512). Modern software, including newer versions of
# Node.js (which Homarr uses, the latest tag was using Node.js v22 in the logs) and the compilers used to build its dependencies, often
# generate code that utilizes these newer instruction sets like AVX for performance improvements.
HOMARR_IMAGE="ghcr.io/homarr-labs/homarr:0.15.10"

DEFAULT_HOST_DATA_DIR="$HOME/.config/homarr-docker"
HOMARR_CONTAINER_BASE_DATA_DIR="/app/data"

HOST_PORT=7575
CONTAINER_PORT=7575

# --- Homarr Specific Environment Variables ---
# Attempt to generate a secure secret key. Requires openssl.
# A 64-character hex string (32 bytes) is needed.
HOMARR_SECRET_KEY=""
if command -v openssl &> /dev/null; then
    HOMARR_SECRET_KEY=$(openssl rand -hex 32)
    echo -e "${GREEN}Generated unique SECRET_ENCRYPTION_KEY.${NC}"
else
    # Fallback to the example from Homarr logs if openssl is not found.
    # WARNING: For better security, install openssl or manually generate and set a unique key.
    HOMARR_SECRET_KEY="deleted-this-as-was-flagged-by-gitleaks" # Example from logs
    echo -e "${YELLOW}⚠️ openssl not found. Using a default example SECRET_ENCRYPTION_KEY.${NC}"
    echo -e "${YELLOW}   It is strongly recommended to generate a unique key for production use.${NC}"
fi


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

# ──[ Installation Logic ]─────────────────────────
if [ -z "$EXISTS" ]; then
    echo
    echo -e "${BOLD}Homarr container '$CONTAINER_NAME' not found. Proceeding with installation.${NC}"

    echo -e "\n${BOLD}Please enter the host folder for Homarr data persistence.${NC}"
    echo -e "Default: ${BLUE_BOLD}${DEFAULT_HOST_DATA_DIR}${NC}"
    read -e -p "Enter Homarr data path [${DEFAULT_HOST_DATA_DIR}]: " user_data_input
    HOST_DATA_DIR="${user_data_input:-$DEFAULT_HOST_DATA_DIR}"

    ensure_dir "$HOST_DATA_DIR"
    echo -e "${GREEN}✅ Host data directory for Homarr checked/ensured: $HOST_DATA_DIR${NC}"
    echo

    echo -e "${CYAN}Pulling latest Homarr image ('${HOMARR_IMAGE}')...${NC}"
    docker pull ${HOMARR_IMAGE}
    if [ $? -ne 0 ]; then
        echo -e "${RED}✖ Failed to pull Homarr image.${NC}"
        exit 1
    fi

    echo -e "${CYAN}Creating and starting Homarr container...${NC}"
    echo -e "${CYAN}Using SECRET_ENCRYPTION_KEY: ${HOMARR_SECRET_KEY}${NC} (first 10 chars shown if long)"


    DOCKER_CMD="docker run -d"
    DOCKER_CMD+=" -p ${HOST_PORT}:${CONTAINER_PORT}"
    DOCKER_CMD+=" --name $CONTAINER_NAME"
    DOCKER_CMD+=" --restart unless-stopped"
    DOCKER_CMD+=" -e SECRET_ENCRYPTION_KEY=\"${HOMARR_SECRET_KEY}\"" # Added environment variable
    DOCKER_CMD+=" -v /var/run/docker.sock:/var/run/docker.sock:ro"
    DOCKER_CMD+=" -v \"$HOST_DATA_DIR\":\"$HOMARR_CONTAINER_BASE_DATA_DIR\""
    DOCKER_CMD+=" ${HOMARR_IMAGE}"

    echo -e "${YELLOW}Executing Docker command:${NC}"
    echo "$DOCKER_CMD" # Consider echo-ing only parts for very long keys if needed
    eval "$DOCKER_CMD"

    if [ $? -ne 0 ]; then
        echo -e "${RED}✖ Failed to start Homarr container. Check Docker logs (${CYAN}docker logs $CONTAINER_NAME${RED}).${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Homarr container '$CONTAINER_NAME' started successfully!${NC}"
else
    ACTUAL_HOST_DATA_DIR=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "'"$HOMARR_CONTAINER_BASE_DATA_DIR"'"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME" 2>/dev/null)
    if [ -z "$ACTUAL_HOST_DATA_DIR" ]; then
        HOST_DATA_DIR=$DEFAULT_HOST_DATA_DIR
    else
        HOST_DATA_DIR=$ACTUAL_HOST_DATA_DIR
    fi
    echo -e "${YELLOW}Homarr container '$CONTAINER_NAME' already exists.${NC}"
    echo -e "${YELLOW}Skipping installation steps.${NC}"
fi

# ──[ Post-Setup Info (Always Shown) ]─────────────
echo
echo -e "${BOLD}📍 Homarr Container Info:${NC}"
echo -e "- Container name: ${CYAN}$CONTAINER_NAME${NC}"
echo -e "- Host directory for data: ${CYAN}$HOST_DATA_DIR${NC}"
echo -e "  (Mapped to ${YELLOW}$HOMARR_CONTAINER_BASE_DATA_DIR${NC} inside container)"
echo -e "- Homarr Web UI (HTTP): Port ${CYAN}${HOST_PORT}${NC}"
echo -e "- SECRET_ENCRYPTION_KEY: ${YELLOW}Set (important for app functionality)${NC}"
echo -e "- Accesses host Docker socket (read-only): ${CYAN}/var/run/docker.sock${NC}"
echo
echo -e "${BOLD}🔧 Initial Setup / Resetting Configuration:${NC}"
echo -e "Access Homarr through your browser. The initial setup is done via the web interface."
echo
echo -e "If you need to ${UNDERLINE}reset Homarr's configuration${NC} or start completely fresh:"
echo -e "1. ${RED}Stop the container:${NC} ${CYAN}docker stop $CONTAINER_NAME${NC}"
echo -e "2. ${RED}Remove the container:${NC} ${CYAN}docker rm $CONTAINER_NAME${NC}"
echo -e "3. ${RED}DELETE the host data directory:${NC} ${CYAN}rm -rf \"$HOST_DATA_DIR\"${NC}"
echo -e "   ${YELLOW}Warning: This will delete all your Homarr configurations, icons, etc.${NC}"
echo -e "4. ${GREEN}Re-run this script.${NC}"
echo
echo -e "${BOLD}🌐 Access Homarr Web UI:${NC}"
echo -e "  Open your web browser and go to: ${YELLOW}http://${HOST_IP}:${HOST_PORT}${NC}"
echo -e "  (Wait a minute for Homarr to initialize fully after starting the container)"
echo
echo -e "${BOLD}⚙️ Common Docker Commands:${NC}"
echo -e "  ${CYAN}docker start|stop|restart $CONTAINER_NAME${NC}"
echo -e "  ${CYAN}docker logs -f $CONTAINER_NAME${NC}"
echo -e "  ${CYAN}docker rm -f $CONTAINER_NAME${NC}"
echo
echo -e "${BOLD}🚀 Next Steps After Accessing Homarr:${NC}"
echo -e "  1. Follow the on-screen instructions in the Homarr web UI."
echo -e "  2. Add your applications, bookmarks, and widgets."
echo

exit 0
