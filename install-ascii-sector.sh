#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root or using sudo."
    exit 1
fi

# Define variables
URL="https://d1.myabandonware.com/t/44a92e83-d646-4a28-bf09-e67f00c59df5/Ascii-Sector_Linux_EN_Version-072-64-bits.gz"
ARCHIVE_NAME="Ascii-Sector_Linux_EN_Version-072-64-bits.gz"
TAR_NAME="Ascii-Sector_Linux_EN_Version-072-64-bits"
INSTALL_DIR="/usr/local/games/asciisec"
EXECUTABLE_NAME="asciisec"

# Check if the installation directory already exists
if [ -d "$INSTALL_DIR" ]; then
    echo "Directory $INSTALL_DIR already exists. Exiting gracefully."
    exit 0
fi

# Function to check file size
check_file_size() {
    local file=$1
    local size=$(stat -c%s "$file")
    local min_size=$((1 * 1024 * 1024)) # 1 MB in bytes
    if [ $size -lt $min_size ]; then
        echo "Downloaded file is less than 1 MB. Possible download error."
        exit 1
    fi
}

# Download the file
wget "$URL" -O "$ARCHIVE_NAME"

# Check file size
check_file_size "$ARCHIVE_NAME"

# Unzip the file to get the tar archive
gunzip "$ARCHIVE_NAME"

# Extract the tar archive to the destination folder
sudo tar -xvf "$TAR_NAME" -C /usr/local/games/

# Make the executable ready to play
sudo chmod +x "$INSTALL_DIR/$EXECUTABLE_NAME"

# Create a symbolic link to make it easier to run the game from anywhere
sudo ln -sf "$INSTALL_DIR/$EXECUTABLE_NAME" /usr/local/bin/ascii_sector

# Clean up
rm -f "$TAR_NAME"

echo "Ascii Sector has been installed and is ready to play! You can start the game by running 'ascii_sector' in the terminal."

