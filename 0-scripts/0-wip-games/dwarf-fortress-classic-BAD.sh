#!/bin/bash

# Dwarf Fortress download URL
DF_URL="https://www.bay12games.com/dwarves/df_47_05_linux.tar.bz2"
INSTALL_DIR="/opt/dwarf_fortress"
SYMLINK="/usr/local/bin/df"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

# Update and ensure required dependencies are installed
echo "Installing required dependencies..."
apt update
apt install -y wget bzip2 libncurses6

# Download and extract Dwarf Fortress
echo "Downloading Dwarf Fortress..."
mkdir -p "$INSTALL_DIR"
wget -O /tmp/df.tar.bz2 "$DF_URL"

echo "Extracting files..."
tar -xjf /tmp/df.tar.bz2 -C "$INSTALL_DIR" --strip-components=1
rm /tmp/df.tar.bz2

# Verify that the game can run in text-only mode
if [[ ! -f "$INSTALL_DIR/df" ]]; then
    echo "Dwarf Fortress executable not found in the extracted files!"
    exit 1
fi

# Set permissions
chmod -R a+rx "$INSTALL_DIR"

# Create symlink for easy execution
echo "Creating symlink..."
ln -sf "$INSTALL_DIR/df" "$SYMLINK"

# Confirm installation
echo "Dwarf Fortress Classic has been installed in $INSTALL_DIR."
echo "You can start it in text-only mode by running: df"

# Check the installation
if "$SYMLINK" --help >/dev/null 2>&1; then
    echo "Installation successful. Have fun playing!"
else
    echo "There was an issue. Please check the installation."
    exit 1
fi

