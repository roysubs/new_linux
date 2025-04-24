#!/bin/bash

# Ensure script is run as root
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script with sudo:"
  echo "  sudo $0"
  exit 1
fi

echo "Checking for Docker installation..."
if ! command -v docker &> /dev/null; then
  echo "Docker not found. Installing..."
  apt-get update
  apt-get install -y docker.io
  systemctl enable docker
  systemctl start docker
else
  echo "Docker is already installed."
fi

# Pull the image if it doesn't exist
IMAGE_NAME="linuxserver/code-server"
echo "Checking for existing Docker image '$IMAGE_NAME'..."
if ! docker image inspect $IMAGE_NAME > /dev/null 2>&1; then
  echo "Image not found locally. Pulling $IMAGE_NAME..."
  docker pull $IMAGE_NAME
else
  echo "Docker image '$IMAGE_NAME' already exists."
fi

CONTAINER_NAME="code-server"
PORT=8088

echo "Checking for '$CONTAINER_NAME' container..."
if ! docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
  echo "The '$CONTAINER_NAME' container does not exist. Creating and running it..."

  docker run -d \
    --name $CONTAINER_NAME \
    -p $PORT:8443 \
    -e PUID=$(id -u) \
    -e PGID=$(id -g) \
    -e TZ=Europe/London \
    -e PASSWORD="changeme" \
    -v "$HOME/code-server-config:/config" \
    linuxserver/code-server
else
  echo "Container '$CONTAINER_NAME' already exists. Starting it if stopped..."
  docker start $CONTAINER_NAME > /dev/null
fi

# Wait briefly to give Docker time to bring up the container
sleep 2

# Check that it's running
if docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
  echo "✅ '$CONTAINER_NAME' is running and should be accessible on:"
  echo "   https://$(hostname -I | awk '{print $1}'):$PORT"
  echo "   Default password: changeme"
else
  echo "❌ Something went wrong. '$CONTAINER_NAME' is not running."
  exit 1
fi

# Show only code-server container in ps output
echo
echo "Docker container status for code-server:"
docker ps --filter "name=code-server"

