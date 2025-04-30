#!/bin/bash

# dwarf-fortress-classic-dk.sh
# Manages the daxiongmao87/dwarf-fortress Docker image for running Dwarf Fortress Classic via SSH.
# Automatically uses ~/.config/dwarf-fortress-docker for persistent storage (bind mount method).
# Provides alternative instructions for using Docker named volumes.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration Variables ---
IMAGE_NAME="daxiongmao87/dwarf-fortress"
# Last console-only version before graphics/sound update
DF_VERSION="47.05"
# Default SSH username inside the container - automatically detected from your system user
SSH_USERNAME="$(whoami)"
# Default SSH password inside the container - !! IMPORTANT: CHANGE THIS PASSWORD BELOW !!
SSH_PASSWORD="changeme"

# Host directory for saving Dwarf Fortress configuration and save data
# This directory will contain 'save' and 'init' subdirectories.
HOST_CONFIG_DIR="$HOME/.config/dwarf-fortress-docker"
HOST_SAVE_DIR="$HOST_CONFIG_DIR/save"
HOST_INIT_DIR="$HOST_CONFIG_DIR/init"
HOST_PORT="2222"

# Docker named volumes for persistence (alternative method)
SAVE_VOLUME_NAME="dwarf_fortress_saves"
INIT_VOLUME_NAME="dwarf_fortress_init"

# --- Image Description (from Docker Hub) ---
IMAGE_DESCRIPTION="Run a SSH-accessible Dwarf Fortress from a container.
This was just a fun experiment, but it seems to be working well.
Requires environment variables USERNAME, PASSWORD, and DF_VERSION (e.g., \"$DF_VERSION\").
Exposes port 22 for SSH access.
Persistent data locations inside container expected by image:
- Save folder: /df/df_linux/data/save
- Init folder: /df/df_linux/data/init"


# --- Validate Configuration ---
if [ "$SSH_PASSWORD" == "changeme" ]; then
    echo "------------------------------------------------------------------"
    echo "!! WARNING: The SSH_PASSWORD variable is still set to 'changeme' !!"
    echo "!! Please edit this script and set a strong password for your   !!"
    echo "!! container's SSH user before running the container.           !!"
    echo "------------------------------------------------------------------"
    # We will still proceed to allow image download/check, but the final run command
    # will reflect this default password, emphasizing the need to change it.
fi


# --- Check if the image exists ---
echo "Checking for Docker image: $IMAGE_NAME (version $DF_VERSION specified)..."

if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "Image '$IMAGE_NAME' found locally."
    IMAGE_EXISTS=true
else
    echo "Image '$IMAGE_NAME' not found locally."
    IMAGE_EXISTS=false

    # --- Describe and Prompt if image is not found ---
    echo ""
    echo "Description:"
    echo "$IMAGE_DESCRIPTION"
    echo ""
    echo "The script will now attempt to download this image from Docker Hub."
    echo ""

    read -p "Do you want to download the image '$IMAGE_NAME'? Press 'y' to continue or any other key to exit: " -n 1 -r
    echo # (optional) add a newline after the prompt

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Proceeding with download..."
        echo "Running: docker pull $IMAGE_NAME"
        if docker pull "$IMAGE_NAME"; then
            echo "Image downloaded successfully."
        else
            echo "Error: Failed to download image '$IMAGE_NAME'. Please check your Docker installation and internet connection."
            exit 1
        fi
    else
        echo ""
        echo "Download cancelled by user. Exiting."
        exit 0 # Exit gracefully if user declines
    fi
fi

# --- Provide instructions on how to run the container ---
echo ""
echo "--- Running Instructions ---"
echo "The Docker image '$IMAGE_NAME' is now available on your system (or was already present)."
echo ""
echo "To run Dwarf Fortress, you need to create and start a container from this image."
echo "This container requires you to set an SSH username, password, and the desired DF version ($DF_VERSION)."
echo ""
echo "IMPORTANT: For your game saves and configuration to persist (not be lost when the container stops or is removed),"
echo "you MUST use Docker's volume mounting feature. Below are two methods:"
echo "1. Using a specific directory on your host machine (bind mount)."
echo "2. Using Docker-managed named volumes."
echo ""
echo "Your configured SSH username will be: $SSH_USERNAME"
echo "Your configured DF version will be: $DF_VERSION"
echo "Remember to set a strong password in the script!"
echo ""

# --- Method 1: Host Directory (Bind Mount) ---
echo "--- Method 1: Using a Host Directory ---"
echo "This method will store your DF saves and config files in:"
echo "  $HOST_CONFIG_DIR"
echo "This directory will be created if it doesn't exist."
echo ""

# Check and create the host directories if they don't exist
if [ ! -d "$HOST_SAVE_DIR" ]; then
    echo "Creating save directory on host: $HOST_SAVE_DIR"
    mkdir -p "$HOST_SAVE_DIR"
fi
if [ ! -d "$HOST_INIT_DIR" ]; then
    echo "Creating init directory on host: $HOST_INIT_DIR"
    mkdir -p "$HOST_INIT_DIR"
fi

echo "Run the container using this command:"
echo "----------------------------------------------------------------------------------------------------"
echo "docker run \\"
echo "  --name dwarf-fortress-classic-host \\"
echo "  -d \\"
echo "  -p $HOST_PORT:22 \\"
echo "  -e USERNAME=\"$SSH_USERNAME\" \\"
echo "  -e PASSWORD=\"$SSH_PASSWORD\" \\"
echo "  -e DF_VERSION=\"$DF_VERSION\" \\"
echo "  -v \"$HOST_SAVE_DIR\":/df/df_linux/data/save \\"
echo "  -v \"$HOST_INIT_DIR\":/df/df_linux/data/init \\"
echo "  $IMAGE_NAME"
echo "----------------------------------------------------------------------------------------------------"
echo "Replace <host_port> with a free port on your machine (e.g., 2222)."
echo ""

# --- Method 2: Docker Named Volumes ---
echo "--- Method 2: Using Docker Named Volumes ---"
echo "This method lets Docker manage where the data is stored. Data is stored in volumes named:"
echo "  $SAVE_VOLUME_NAME"
echo "  $INIT_VOLUME_NAME"
echo ""
echo "First, create the named volumes (if they don't already exist):"
echo "docker volume create $SAVE_VOLUME_NAME"
echo "docker volume create $INIT_VOLUME_NAME"
echo ""
echo "Then, run the container using this command:"
echo "----------------------------------------------------------------------------------------------------"
echo "docker run \\"
echo "  --name dwarf-fortress-classic-volume \\"
echo "  -d \\"
echo "  -p $HOST_PORT:22 \\"
echo "  -e USERNAME=\"$SSH_USERNAME\" \\"
echo "  -e PASSWORD=\"$SSH_PASSWORD\" \\"
echo "  -e DF_VERSION=\"$DF_VERSION\" \\"
echo "  -v $SAVE_VOLUME_NAME:/df/df_linux/data/save \\"
echo "  -v $INIT_VOLUME_NAME:/df/df_linux/data/init \\"
echo "  $IMAGE_NAME"
echo "----------------------------------------------------------------------------------------------------"
echo "Replace <host_port> with a free port on your machine (e.g., 2222)."
echo ""

echo "After running either command (and replacing <host_port>):"
echo "You can connect to your Dwarf Fortress instance via SSH:"
echo "ssh $SSH_USERNAME@<your_host_ip_or_hostname> -p <host_port>"
echo "Enter the password '$SSH_PASSWORD' you set when prompted."
echo "(Remember to change the password in the script before running the container!)"
echo ""

echo "Script finished."

exit 0
