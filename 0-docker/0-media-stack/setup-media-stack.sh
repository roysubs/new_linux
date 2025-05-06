#!/bin/bash

# Example of a complete stack

set -e

CONFIG_DIR="$(pwd)/config"
ENV_FILE=".env"
BASE_MEDIA="/mnt/media"

DOCKER_COMPOSE_FILE="docker-compose.yaml"

echo "🔍 Parsing docker-compose.yaml..."

# Extract container names
CONTAINER_NAMES=($(yq '.services | keys | .[]' "$DOCKER_COMPOSE_FILE"))


# Extract image names
IMAGES=($(yq '.services.*.image' "$DOCKER_COMPOSE_FILE"))

# Extract host ports (the part before ':' in port bindings)
PORTS=($(yq '.services.*.ports[]' "$DOCKER_COMPOSE_FILE" | cut -d: -f1 | grep -E '^[0-9]+$' | sort -u))

echo "Container Names: ${CONTAINER_NAMES[@]}"
echo "Imags: ${IMAGES[@]}"
echo "Ports: ${PORTS[@]}"

# Check for container name conflicts
echo "🔎 Checking for existing containers that could conflict..."
for name in "${CONTAINER_NAMES[@]}"; do
  if docker ps -a --format '{{.Names}}' | grep -wq "$name"; then
    echo "❌ A container named \"$name\" already exists. Remove it with:"
    echo "   docker rm -f $name"
    exit 1
  fi
done

# Check if any listed image is already in use
echo "🔎 Checking for running containers using images from this compose file..."
EXISTING_CONTAINERS=$(docker ps --format '{{.Names}} {{.Image}}')
CONFLICTING_IMAGES=()
for img in "${IMAGES[@]}"; do
  if echo "$EXISTING_CONTAINERS" | grep -q "$img"; then
    CONFLICTING_IMAGES+=("$img")
  fi
done

if [ "${#CONFLICTING_IMAGES[@]}" -gt 0 ]; then
  echo "⚠️  WARNING: The following images are already used by running containers:"
  for img in "${CONFLICTING_IMAGES[@]}"; do
    echo "   - $img"
  done
  read -p "Continue anyway? (y/N): " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
fi

# Check for port conflicts
echo "🔎 Checking for port conflicts..."
for port in "${PORTS[@]}"; do
  if ss -tuln | grep -q ":$port "; then
    echo "❌ Port $port is already in use. Please stop the service using it or change the docker-compose config."
    exit 1
  fi
done

echo "✅ No conflicts found. Proceeding..."

# Check Docker
if ! command -v docker &> /dev/null; then
  echo "Docker not found. Installing..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  echo "Docker installed. Please log out and back in to apply group changes."
  exit 1
else
  echo "Docker is already installed."
fi

# Check Docker Compose plugin
if ! docker compose version &>/dev/null; then
  echo "Docker Compose plugin not found. Installing..."
  DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
  mkdir -p "$DOCKER_CONFIG/cli-plugins"
  curl -SL https://github.com/docker/compose/releases/download/v2.27.1/docker-compose-linux-$(uname -m) \
    -o "$DOCKER_CONFIG/cli-plugins/docker-compose"
  chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"
  echo "Docker Compose plugin installed."
fi

# Detect UID and GID
PUID=$(id -u)
PGID=$(id -g)

echo "Using UID=$PUID and GID=$PGID"

# Check/create media base folder
if [ ! -d "$BASE_MEDIA" ]; then
  echo "Base media directory $BASE_MEDIA does not exist."
  read -p "Enter path to your actual media location (to bind to /mnt/media): " SOURCE_PATH
  sudo mkdir -p "$SOURCE_PATH"
  sudo mkdir -p "$BASE_MEDIA"
  sudo mount --bind "$SOURCE_PATH" "$BASE_MEDIA"
  echo "Mounted $SOURCE_PATH to $BASE_MEDIA"
fi

# Create folders
mkdir -p "$BASE_MEDIA/downloads/movies" "$BASE_MEDIA/downloads/tv"
mkdir -p "$BASE_MEDIA/movies" "$BASE_MEDIA/tv"
mkdir -p "$CONFIG_DIR"/{gluetun,qbittorrent,sonarr,radarr,jackett,filebrowser}
chown -R "$PUID:$PGID" "$BASE_MEDIA"

# Get VPN credentials
read -p "Enter your Surfshark username: " VPNUSER
read -s -p "Enter your Surfshark password: " VPNPASS
echo

# Create .env file
cat > "$ENV_FILE" <<EOF
VPNUSER=$VPNUSER
VPNPASS=$VPNPASS
PUID=$PUID
PGID=$PGID
EOF

# Launch the stack
docker compose --env-file "$ENV_FILE" up -d
rm -f "$ENV_FILE"

echo "✅ Media stack is up and running!"

