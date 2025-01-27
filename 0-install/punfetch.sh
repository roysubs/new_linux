#!/bin/bash

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (e.g., sudo ./install_punfetch.sh)"
  exit 1
fi

# Update package lists
echo "Updating package lists..."
apt update -y

# Install git if not already installed
if ! command -v git &>/dev/null; then
  echo "Installing git..."
  apt install -y git
else
  echo "Git is already installed."
fi

# Clone the punfetch repository

git clone https://github.com/ozwaldorf/punfetch.git

REPO_URL="git clone https://github.com/ozwaldorf/punfetch.git"
INSTALL_DIR="/opt/punfetch"

if [ ! -d "$INSTALL_DIR" ]; then
  echo "Cloning punfetch repository..."
  git clone "$REPO_URL" "$INSTALL_DIR"
else
  echo "Punfetch is already cloned in $INSTALL_DIR. Updating..."
  git -C "$INSTALL_DIR" pull
fi

cd /opt/punfetch
make install

# Create a symlink to make punfetch globally accessible
echo "Creating symlink..."
ln -sf "$INSTALL_DIR/punfetch" /usr/local/bin/punfetch

# Verify the installation
if command -v punfetch &>/dev/null; then
  echo "Punfetch has been successfully installed! Run 'punfetch' to use it."
else
  echo "There was an issue installing punfetch. Please check the script output."
fi

