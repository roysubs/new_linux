#!/bin/bash

# Define container parameters
CONTAINER_NAME="kolourpaint"
VNC_PORT=6901 # Default port for web access to linuxserver/webtop
APP_TO_INSTALL="kolourpaint" # The GUI application to install

# Check if Docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker is not installed. Please install Docker and rerun."
    echo "See instructions: https://docs.docker.com/engine/install/"
    exit 1
fi

# Stop and remove existing container if it exists
if docker inspect "$CONTAINER_NAME" &> /dev/null; then
    echo "Stopping and removing existing container '$CONTAINER_NAME'..."
    docker stop "$CONTAINER_NAME"
    docker rm "$CONTAINER_NAME"
fi

# Pull the linuxserver/webtop image (using KDE desktop as an example)
# You can change kde to cinnamon, mate, xfce, etc.
echo "Pulling the linuxserver/webtop image..."
docker pull lscr.io/linuxserver/webtop:latest

# Run the container
echo "Running the '$CONTAINER_NAME' container..."
docker run -d \
    --name="$CONTAINER_NAME" \
    -p $VNC_PORT:$VNC_PORT \
    -e PUID=$(id -u) \
    -e PGID=$(id -g) \
    -e TZ=Etc/UTC \
    -e DOCKER_MODS=linuxserver/mods:universal-packages \
    -v webtop_config:/config \
    --restart unless-stopped \
    lscr.io/linuxserver/webtop:latest

echo "Container '$CONTAINER_NAME' is starting..."
echo "Waiting for the container to be ready..."

# Wait a bit for the container to start (adjust as needed)
sleep 30

# Install the GUI application inside the running container
echo "Installing '$APP_TO_INSTALL' inside the container..."
docker exec "$CONTAINER_NAME" apt-get update
docker exec "$CONTAINER_NAME" apt-get install -y "$APP_TO_INSTALL"

echo "Setup complete!"
echo "The GUI application '$APP_TO_INSTALL' is installed in the container."
echo "You should be able to access the desktop environment and run the application."
echo "Instructions to access from Windows will follow."
