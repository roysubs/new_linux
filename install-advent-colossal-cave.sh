#!/bin/bash

# Script to install the "Advent" game on Debian

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Use sudo or log in as root."
  exit 1
fi

echo "Updating package lists..."
apt update

echo "Installing required dependencies..."
apt install -y build-essential bison flex git unzip

# Set up variables
REPO_URL="https://github.com/troglobit/advent.git"
TMP_DIR="/tmp/advent-install"
INSTALL_DIR="/usr/local/bin"

echo "Creating temporary directory for installation..."
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

echo "Cloning the Advent source code repository..."
git clone "$REPO_URL" advent
cd advent

echo "Building the game..."
make

echo "Installing the game to $INSTALL_DIR..."
make PREFIX="$INSTALL_DIR" install

echo "Cleaning up temporary files..."
cd /
rm -rf "$TMP_DIR"

echo "Installation complete! You can run the game using the command: advent"

