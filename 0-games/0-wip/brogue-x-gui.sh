#!/bin/bash

# Define the location where BrogueCE will be installed
# The game files will go here
INSTALL_SHARE_DIR="$HOME/.local/share/brogue-ce"
# A symlink to the executable will go here
INSTALL_BIN_DIR="$HOME/.local/bin"
BROGUE_EXEC_LINK="$INSTALL_BIN_DIR/brogue"

# Ensure necessary commands are available
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed. Please install it first."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first (e.g., sudo apt-get install jq or sudo dnf install jq)."
    exit 1
fi

if ! command -v wget &> /dev/null; then
    echo "Error: wget is not installed. Please install it first."
    exit 1
fi

if ! command -v tar &> /dev/null; then
    echo "Error: tar is not installed. Please install it first."
    exit 1
fi

# Function to download and install BrogueCE
install_broguece() {
    echo "BrogueCE not found, installing the latest version..."

    # Get the latest release download URL for the Linux tarball (x86_64)
    LATEST_URL=$(curl -s https://api.github.com/repos/tmewett/BrogueCE/releases/latest | jq -r ".assets[] | select(.name | test(\".*linux-x86_64.tar.gz$\")) | .browser_download_url")

    if [ -z "$LATEST_URL" ]; then
        echo "Error: Could not find the latest BrogueCE release URL for Linux."
        echo "Please check the releases page manually: https://github.com/tmewett/BrogueCE/releases"
        exit 1
    fi

    # Define download and extraction paths
    DOWNLOAD_TARBALL="$HOME/broguece-latest.tar.gz"

    # Download the tarball
    echo "Downloading BrogueCE from $LATEST_URL..."
    wget --show-progress "$LATEST_URL" -O "$DOWNLOAD_TARBALL"

    # Create the installation directory for game files
    echo "Creating installation directory: $INSTALL_SHARE_DIR..."
    mkdir -p "$INSTALL_SHARE_DIR"

    # Extract the tarball into the installation directory
    echo "Extracting BrogueCE to $INSTALL_SHARE_DIR..."
    # Find the top-level directory inside the tarball
    TAR_TOP_DIR=$(tar -tf "$DOWNLOAD_TARBALL" | head -1 | sed -e 's/\/.*//')
    if [ -z "$TAR_TOP_DIR" ]; then
        echo "Error: Could not determine the top-level directory in the tarball."
        rm "$DOWNLOAD_TARBALL"
        exit 1
    fi

    tar -xzf "$DOWNLOAD_TARBALL" -C "$INSTALL_SHARE_DIR" --strip-components=1

    # Define the path to the actual brogue executable within the installed files
    BROGUE_EXEC_PATH="$INSTALL_SHARE_DIR/bin/brogue"

    # Check if the brogue executable exists after extraction
    if [ ! -f "$BROGUE_EXEC_PATH" ]; then
        echo "Error: Could not find 'brogue' executable in the extracted files."
        echo "Expected path: $BROGUE_EXEC_PATH"
        # List extracted files for debugging
        echo "Listing contents of $INSTALL_SHARE_DIR:"
        ls -R "$INSTALL_SHARE_DIR"
        rm -rf "$INSTALL_SHARE_DIR"
        rm "$DOWNLOAD_TARBALL"
        exit 1
    fi

    # Create the bin directory if it doesn't exist
    mkdir -p "$INSTALL_BIN_DIR"

    # Create a symbolic link to the executable in the bin directory
    echo "Creating symbolic link for 'brogue' in $INSTALL_BIN_DIR..."
    ln -sf "$BROGUE_EXEC_PATH" "$BROGUE_EXEC_LINK"

    # Cleanup the downloaded tarball
    rm "$DOWNLOAD_TARBALL"

    echo "BrogueCE installation completed successfully."
}

# Check if the brogue executable symlink already exists and points to a file
if [ -f "$BROGUE_EXEC_LINK" ] && [ -x "$BROGUE_EXEC_LINK" ]; then
    echo "BrogueCE appears to be already installed."
else
    install_broguece
fi

# Ensure the installation directory for executables is on the PATH
if [[ ":$PATH:" != *":$INSTALL_BIN_DIR:"* ]]; then
    echo "Adding $INSTALL_BIN_DIR to PATH..."
    # Add to .bashrc or .zshrc depending on the shell
    SHELL_RC="$HOME/.$(basename "$SHELL")rc"
    if [ -f "$SHELL_RC" ]; then
        echo "export PATH=\"$INSTALL_BIN_DIR:\$PATH\"" >> "$SHELL_RC"
        # Source the file to update PATH in the current session
        source "$SHELL_RC"
        echo "$INSTALL_BIN_DIR added to PATH in $SHELL_RC."
        echo "You may need to open a new terminal session for the PATH change to take effect."
    else
        echo "Warning: Could not find shell rc file ($SHELL_RC) to add $INSTALL_BIN_DIR to PATH."
        echo "Please manually add '$INSTALL_BIN_DIR' to your PATH environment variable."
    fi
else
    echo "$INSTALL_BIN_DIR is already in the PATH."
fi

echo "Installation check complete. If installation just ran, you should now be able to run 'brogue'."
echo "If you installed for the first time and your shell rc file was updated, you may need to open a new terminal."
