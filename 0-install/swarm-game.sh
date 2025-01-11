#!/bin/bash
#
# https://github.com/swarm-game/swarm/
# https://swarm-game.github.io/
# https://swarm-game.github.io/installing/#installing-via-binaries
# https://byorgey.wordpress.com/2022/06/20/swarm-status-report/

# Exit script on any error
# set -e

# Define constants
REPO_URL="https://github.com/swarm-game/swarm/releases"
INSTALL_DIR="$HOME/.local/share/swarm"
BIN_DIR="$HOME/.local/bin"

# Ensure required directories exist
mkdir -p "$INSTALL_DIR" "$BIN_DIR"

# Fetch latest release page
LATEST_RELEASE=$(curl -sL "$REPO_URL/latest")

# Extract asset download URLs
BINARY_URL=$(echo "$LATEST_RELEASE" | grep -oP '(?<=href=")/swarm-game/swarm/releases/download/[^"]*/swarm-Linux')
DATA_URL=$(echo "$LATEST_RELEASE" | grep -oP '(?<=href=")/swarm-game/swarm/releases/download/[^"]*/swarm-data.zip')

if [[ -z "$BINARY_URL" || -z "$DATA_URL" ]]; then
  echo "Error: Could not find download URLs. Exiting."
  exit 1
fi

# Prefix URLs with the base GitHub URL
BINARY_URL="https://github.com$BINARY_URL"
DATA_URL="https://github.com$DATA_URL"

# Download the binary
BINARY_PATH="swarm-Linux"
echo "Downloading binary from $BINARY_URL..."
curl -L -o "$BINARY_PATH" "$BINARY_URL"
chmod +x "$BINARY_PATH"
mv "$BINARY_PATH" "$BIN_DIR/swarm"

# Download and extract the data
DATA_ARCHIVE="swarm-data.zip"
echo "Downloading data from $DATA_URL..."
curl -L -o "$DATA_ARCHIVE" "$DATA_URL"
unzip -o "$DATA_ARCHIVE" -d "$INSTALL_DIR"
rm "$DATA_ARCHIVE"

# Inform the user
echo "Swarm has been installed successfully!"
echo "Binary location: $BIN_DIR/swarm"
echo "Data directory: $INSTALL_DIR"
echo "Make sure $BIN_DIR is in your PATH. You can add it with the following command if necessary:"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc" && source "$HOME/.bashrc"

