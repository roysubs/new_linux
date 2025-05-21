#!/bin/bash

# Script to download and install Infra Arcana
# This script will:
# 1. Check for and install dependencies
# 2. Download the latest binary release
# 3. Install both terminal and graphical modes if available
# 4. Create a symlink for easy execution

set -e  # Exit on error
echo "=== Infra Arcana Installation Script ==="

# Create a temporary directory for downloads
TEMP_DIR=$(mktemp -d)
INSTALL_DIR="$HOME/.local/games/infra_arcana"
BIN_LINK_DIR="$HOME/.local/bin"

# Make sure the binary link directory exists and is in PATH
mkdir -p "$BIN_LINK_DIR"
if [[ ":$PATH:" != *":$BIN_LINK_DIR:"* ]]; then
    echo "Adding $BIN_LINK_DIR to your PATH in .bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/.local/bin:$PATH"
    echo "NOTE: You'll need to restart your terminal or run 'source ~/.bashrc' for the PATH changes to take effect"
fi

# Function to check and install dependencies
install_dependencies() {
    echo "Checking and installing dependencies..."
    
    # Package lists for different distros
    DEBIAN_DEPS="libsdl2-2.0-0 libsdl2-image-2.0-0 libsdl2-ttf-2.0-0 wget unzip"
    FEDORA_DEPS="SDL2 SDL2_image SDL2_ttf wget unzip"
    ARCH_DEPS="sdl2 sdl2_image sdl2_ttf wget unzip"
    
    if command -v apt-get &> /dev/null; then
        echo "Debian/Ubuntu detected"
        sudo apt-get update
        sudo apt-get install -y $DEBIAN_DEPS
    elif command -v dnf &> /dev/null; then
        echo "Fedora detected"
        sudo dnf install -y $FEDORA_DEPS
    elif command -v pacman &> /dev/null; then
        echo "Arch Linux detected"
        sudo pacman -Sy --noconfirm $ARCH_DEPS
    else
        echo "Warning: Could not detect package manager. You may need to install dependencies manually:"
        echo "- SDL2"
        echo "- SDL2_image"
        echo "- SDL2_ttf"
        echo "- wget"
        echo "- unzip"
    fi
}

# Function to download and install the latest release
download_and_install() {
    echo "Downloading the latest Infra Arcana release..."
    
    # Go to temp directory
    cd "$TEMP_DIR"
    
    # Get the latest release from GitHub
    GITHUB_REPO="https://github.com/InfraArcana/ia"
    LATEST_RELEASE_URL=$(wget -qO- "https://api.github.com/repos/InfraArcana/ia/releases/latest" | 
                         grep '"browser_download_url"' | 
                         grep -i "linux" | 
                         grep -v ".asc" | 
                         head -n 1 | 
                         cut -d '"' -f 4)
    
    if [ -z "$LATEST_RELEASE_URL" ]; then
        echo "Could not find the latest release. Attempting to use the releases page directly..."
        LATEST_RELEASE_URL=$(wget -qO- "https://github.com/InfraArcana/ia/releases" | 
                            grep -o 'href="[^"]*linux[^"]*\.zip"' | 
                            head -n 1 | 
                            sed 's/href="/https:\/\/github.com/g' | 
                            sed 's/"//g')
    fi
    
    if [ -z "$LATEST_RELEASE_URL" ]; then
        echo "Failed to find a Linux release. Trying alternative repository..."
        # Try Martin's fork which is actively maintained
        GITHUB_REPO="https://github.com/martin-tornqvist/ia"
        LATEST_RELEASE_URL=$(wget -qO- "https://api.github.com/repos/martin-tornqvist/ia/releases/latest" | 
                             grep '"browser_download_url"' | 
                             grep -i "linux" | 
                             grep -v ".asc" | 
                             head -n 1 | 
                             cut -d '"' -f 4)
    fi
    
    if [ -z "$LATEST_RELEASE_URL" ]; then
        echo "Error: Could not determine the download URL for Infra Arcana"
        exit 1
    fi
    
    echo "Downloading from: $LATEST_RELEASE_URL"
    ARCHIVE_NAME=$(basename "$LATEST_RELEASE_URL")
    wget -O "$ARCHIVE_NAME" "$LATEST_RELEASE_URL"
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    
    # Extract the archive
    echo "Extracting files..."
    if [[ "$ARCHIVE_NAME" == *.zip ]]; then
        unzip "$ARCHIVE_NAME" -d "$TEMP_DIR/extracted"
    elif [[ "$ARCHIVE_NAME" == *.tar.gz ]]; then
        mkdir -p "$TEMP_DIR/extracted"
        tar -xzf "$ARCHIVE_NAME" -C "$TEMP_DIR/extracted"
    else
        echo "Error: Unknown archive format. Supported formats: .zip, .tar.gz"
        exit 1
    fi
    
    # Find the extracted directory
    EXTRACTED_DIR="$TEMP_DIR/extracted"
    if [ ! -d "$EXTRACTED_DIR" ]; then
        echo "Error: Extraction failed or directory structure unexpected"
        exit 1
    fi
    
    # Check for nested directory structure (common with archives)
    NESTED_DIR=$(find "$EXTRACTED_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    if [ -n "$NESTED_DIR" ] && [ "$(ls -A "$NESTED_DIR" | wc -l)" -gt 0 ]; then
        echo "Found nested directory: $(basename "$NESTED_DIR")"
        EXTRACTED_DIR="$NESTED_DIR"
    fi
    
    # Move all files to the installation directory
    echo "Installing to $INSTALL_DIR..."
    cp -r "$EXTRACTED_DIR"/* "$INSTALL_DIR"/ 2>/dev/null || cp -r "$EXTRACTED_DIR"/.* "$INSTALL_DIR"/ 2>/dev/null || true
    
    # Make binaries executable
    chmod +x "$INSTALL_DIR"/ia "$INSTALL_DIR"/*.sh 2>/dev/null || true
    
    # Create symlinks for easy access
    echo "Creating symlinks..."
    ln -sf "$INSTALL_DIR/ia" "$BIN_LINK_DIR/ia"
    
    # Check if there are separate terminal and graphical binaries
    if [ -f "$INSTALL_DIR/ia_term" ]; then
        chmod +x "$INSTALL_DIR/ia_term"
        ln -sf "$INSTALL_DIR/ia_term" "$BIN_LINK_DIR/ia_term"
        echo "Terminal interface symlink created: ia_term"
    fi
    
    if [ -f "$INSTALL_DIR/ia_sdl" ]; then
        chmod +x "$INSTALL_DIR/ia_sdl"
        ln -sf "$INSTALL_DIR/ia_sdl" "$BIN_LINK_DIR/ia_sdl"
        echo "Graphical interface symlink created: ia_sdl"
    fi
}

# Run the installation
install_dependencies
download_and_install

# Clean up
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo "=== Installation Complete ==="
echo ""
echo "To play Infra Arcana:"
echo "  Graphical mode: ia or infra-arcana"
echo "  Text mode: ia_text"
echo ""
echo "NOTE: If you get 'command not found', you need to either:"
echo "  1. Run the command: source ~/.bashrc"
echo "  2. Start a new terminal session"
echo ""
echo "If you encounter a segmentation fault with the graphical version:"
echo "  1. Try the text mode with: ia_text"
echo "  2. Or run from the game directory: cd $(dirname "$GAME_EXEC") && ./ia"
echo ""
echo "Infra Arcana - Game Controls Summary:"
echo "------------------------------------"
echo "Movement: Arrow keys or numpad (8/2/4/6 for cardinal directions, 7/9/1/3 for diagonals)"
echo "Wait: Space or 5 on numpad"
echo "Pick up item: g or comma (,)"
echo "Inventory: i"
echo "Equipment: e"
echo "Look around: l or x"
echo "Open/close door: o/c"
echo "Go up/down stairs: < / >"
echo "Cast spell: z"
echo "Reload weapon: r"
echo "Fire ranged weapon: f"
echo "Throw item: t"
echo "Apply/use item: a"
echo "Help: ? (shows all commands)"
echo "Save and quit: S"
echo "Quit without saving: Q"
echo ""
echo "Enjoy your journey into cosmic horror!"
