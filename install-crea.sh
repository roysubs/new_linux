#!/bin/bash

# Ensure the script is run as root (or using sudo)
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root or with sudo." 
    exit 1
fi

# Install necessary dependencies
echo "Installing necessary dependencies..."
sudo apt update
sudo apt install -y cmake libsdl2-dev libboost-all-dev git

# Clone the Crea repository
echo "Cloning the Crea repository..."
git clone https://github.com/paulcuth/crea.git

# Build and install Crea
echo "Building Crea..."
cd crea || { echo "Failed to enter 'crea' directory"; exit 1; }
mkdir build
cd build || { echo "Failed to enter 'build' directory"; exit 1; }
cmake ..
make

# Install Crea
echo "Installing Crea..."
sudo make install

# Clean up
cd ../../
rm -rf crea

echo "Crea installation complete!"

