#!/bin/bash

# Define the release version and file name
BROGUE_VERSION="1.14.1"
BROGUE_ARCHIVE="BrogueCE-${BROGUE_VERSION}-linux-x86_64.tar.gz"
DOWNLOAD_URL="https://github.com/tmewett/BrogueCE/releases/download/v${BROGUE_VERSION}/${BROGUE_ARCHIVE}"
INSTALL_DIR="$HOME/broguece_terminal"

# --- Script Start ---

echo "BrogueCE Terminal Installation Script"
echo "------------------------------------"

# Check if curl is installed
if ! command -v curl &> /dev/null
then
    echo "Error: curl is not installed. Please install curl to proceed."
    echo "On Debian/Ubuntu: sudo apt update && sudo apt install curl"
    echo "On Fedora: sudo dnf install curl"
    echo "On Arch: sudo pacman -S curl"
    exit 1
fi

# Check if tar is installed
if ! command -v tar &> /dev/null
then
    echo "Error: tar is not installed. Please install tar to proceed."
    echo "On Debian/Ubuntu: sudo apt update && sudo apt install tar"
    echo "On Fedora: sudo dnf install tar"
    echo "On Arch: sudo pacman -S tar"
    exit 1
fi


# Create installation directory if it doesn't exist
if [ -d "$INSTALL_DIR" ]; then
    echo "Installation directory '$INSTALL_DIR' already exists."
    read -p "Do you want to remove it and proceed with a clean install? (y/N): " response
    if [[ "$response" =~ ^[yY]$ ]]; then
        echo "Removing existing directory..."
        rm -rf "$INSTALL_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to remove existing directory. Aborting."
            exit 1
        fi
        mkdir -p "$INSTALL_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create installation directory '$INSTALL_DIR'. Aborting."
            exit 1
        fi
    else
        echo "Aborting installation."
        exit 0
    fi
else
    echo "Creating installation directory '$INSTALL_DIR'..."
    mkdir -p "$INSTALL_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create installation directory '$INSTALL_DIR'. Aborting."
        exit 1
    fi
fi


# Download the archive
echo "Downloading BrogueCE v${BROGUE_VERSION} terminal build..."
echo "From: ${DOWNLOAD_URL}"
curl -L "${DOWNLOAD_URL}" -o "${INSTALL_DIR}/${BROGUE_ARCHIVE}"
if [ $? -ne 0 ]; then
    echo "Error: Download failed. Please check the URL and your internet connection."
    exit 1
fi
echo "Download complete."

# Extract the archive
echo "Extracting the archive..."
tar -xzf "${INSTALL_DIR}/${BROGUE_ARCHIVE}" -C "$INSTALL_DIR" --strip-components=1
if [ $? -ne 0 ]; then
    echo "Error: Extraction failed."
    echo "Attempting to clean up downloaded file..."
    rm "${INSTALL_DIR}/${BROGUE_ARCHIVE}"
    exit 1
fi
echo "Extraction complete."

# Clean up the downloaded archive
echo "Cleaning up downloaded archive..."
rm "${INSTALL_DIR}/${BROGUE_ARCHIVE}"
if [ $? -ne 0 ]; then
    echo "Warning: Failed to remove the downloaded archive file."
fi
echo "Cleanup complete."

# Provide instructions
echo "------------------------------------"
echo "BrogueCE v${BROGUE_VERSION} terminal version installed successfully!"
echo "To play the game, navigate to the installation directory and run the brogue executable:"
echo "cd \"$INSTALL_DIR\""
echo "./brogue"
echo "------------------------------------"

exit 0

