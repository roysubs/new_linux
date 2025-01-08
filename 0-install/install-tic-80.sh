#!/bin/bash

# Install and configure TIC-80, a tiny fantasy computer for creating, playing, and sharing games. This script downloads the latest version of TIC-80, installs its dependencies, and configures it for use.
# Dependencies: Ensures required libraries (libgl1, libpulse0, libx11-6) are installed.
# Download and Extract: Downloads the latest TIC-80 release as a zip file and extracts it to /opt/tic80.
# Symbolic Link: Creates a symbolic link in /usr/local/bin for global accessibility.
# Cleanup: Removes the downloaded zip file after extraction.
# Verification: Checks if TIC-80 was installed successfully by running tic80 --version.
# Desktop Shortcut: Optionally creates a .desktop file for launching TIC-80 from the system menu.

# TIC-80 provides a virtual environment where users can create, play, and share retro-style games using a built-in IDE that includes a code editor, sprite editor, map editor, and sound/music tools. The graphical interface is integral to its functionality, as it's designed to simulate a fantasy retro computer.
# Users interact with its tools and games visually, making it well-suited for both game development and gameplay.

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to display messages
echo_info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

echo_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
    exit 1
}

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo_error "This script must be run as root. Please use sudo or switch to the root user."
fi

# Variables
TIC80_DOWNLOAD_URL="https://tic80.com/download/latest/tic80-linux.zip"
TIC80_INSTALL_DIR="/opt/tic80"
TIC80_BIN="/usr/local/bin/tic80"

# Update package lists and install dependencies
echo_info "Updating package lists and installing dependencies..."
apt update && apt install -y wget unzip libgl1 libpulse0 libx11-6

# Create installation directory
echo_info "Creating TIC-80 installation directory at $TIC80_INSTALL_DIR..."
mkdir -p "$TIC80_INSTALL_DIR"

# Download the latest TIC-80 release
echo_info "Downloading TIC-80 from $TIC80_DOWNLOAD_URL..."
wget -O /tmp/tic80.zip "$TIC80_DOWNLOAD_URL"

# Extract TIC-80 to the installation directory
echo_info "Extracting TIC-80 to $TIC80_INSTALL_DIR..."
unzip /tmp/tic80.zip -d "$TIC80_INSTALL_DIR"

# Create a symbolic link to make TIC-80 globally accessible
echo_info "Creating a symbolic link at $TIC80_BIN..."
ln -sf "$TIC80_INSTALL_DIR/tic80" "$TIC80_BIN"

# Clean up
echo_info "Cleaning up temporary files..."
rm -f /tmp/tic80.zip

# Test TIC-80 installation
echo_info "Testing TIC-80 installation..."
if tic80 --version &>/dev/null; then
    echo_info "TIC-80 installed successfully!"
else
    echo_error "TIC-80 installation failed. Please check for errors above."
fi

# Configuration: Create a desktop shortcut (optional)
read -p "Would you like to create a desktop shortcut for TIC-80? (y/n): " create_shortcut
if [[ "$create_shortcut" =~ ^[Yy]$ ]]; then
    DESKTOP_FILE="/usr/share/applications/tic80.desktop"
    echo_info "Creating desktop shortcut at $DESKTOP_FILE..."
    cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=TIC-80
Exec=$TIC80_BIN
Icon=$TIC80_INSTALL_DIR/logo.png
Type=Application
Categories=Development;Game;
EOF
    echo_info "Desktop shortcut created successfully!"
fi

echo_info "TIC-80 installation and configuration completed."

