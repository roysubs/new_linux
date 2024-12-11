#!/bin/bash

# Function to check and install missing dependencies
install_dependency() {
  if ! command -v "$1" &> /dev/null; then
    echo "Installing $1..."
    sudo apt-get install -y "$2"
  else
    echo "$1 is already installed."
  fi
}

# Update package list
echo "Updating package list..."
sudo apt-get update -y

# Install prerequisites for building tools
echo "Installing prerequisites..."
install_dependency "curl" "curl"
install_dependency "git" "git"
install_dependency "node" "nodejs"
install_dependency "npm" "npm"

# Install btop
echo "Installing btop..."
sudo apt-get install -y btop
echo "btop installed."
# Deprecated variants
# pip install --user bpytop   # bpytop python clone is deprecated.
# git clone https://github.com/aristocratos/bashtop.git && cd bashtop   # bashtop is deprecated.
# sudo make install && cd .. && rm -rf bashtop

# Install htop
echo "Installing htop..."
sudo apt-get install -y htop

# Install atop
sudo apt install -y atop

# Install gtop (using npm)
echo "Installing gtop..."
sudo npm install -g gtop

# Install ytop
curl -LO https://github.com/cjbassi/ytop/releases/download/0.6.2/ytop_0.6.2_amd64.deb
sudo dpkg -i ytop_0.6.2_amd64.deb
rm -f ytop_*_amd64.deb

# Install vtop
echo "Installing vtop..."
sudo npm install -g vtop

# Final update and cleanup
echo "Cleaning up..."
sudo apt-get autoremove -y && sudo apt-get clean

echo "All tools installed!"

