#!/bin/bash

# Set variables for directories and file names
SOURCE_DIR="/tmp/source_code"
BUILD_DIR="/tmp/build"
INSTALL_DIR="/usr/local"

# Ensure the system is up-to-date and install dependencies
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing dependencies..."
sudo apt install -y build-essential \
    libasound2-dev \
    libbrotli-dev \
    libbz2-dev \
    libdbus-1-dev \
    libglib2.0-dev \
    libicu-dev \
    libpng-dev \
    libfreetype-dev \
    libjpeg-dev \
    libx11-dev \
    libxrandr-dev \
    libsdl2-dev \
    git \
    cmake

# Clean any pre-existing source or build directories
echo "Cleaning up previous builds..."
rm -rf $SOURCE_DIR $BUILD_DIR

# Clone the repository or download source code (replace with actual repo or URL)
echo "Cloning repository..."
git clone https://gitlab.com/martin-tornqvist/ia.git $SOURCE_DIR

# Navigate to source directory and configure with CMake
echo "Configuring the software with CMake..."
mkdir -p $BUILD_DIR
cd $BUILD_DIR
cmake $SOURCE_DIR -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR

# Compile the software
echo "Compiling the software..."
make -j$(nproc)

# Install the compiled software
echo "Installing the software..."
sudo make install

# Clean up the source and build directories
echo "Cleaning up after installation..."
# rm -rf $SOURCE_DIR $BUILD_DIR

# Verify installation
echo "Verifying installation..."
which software_name

echo "Installation and cleanup complete!"

