#!/bin/bash

# Define the location where mdcat will be installed
INSTALL_DIR="$HOME/.local/bin"
MD_CAT_BIN="$INSTALL_DIR/mdcat"
README_FILE="$INSTALL_DIR/mdcat-README.md"

# Function to download and install mdcat
install_mdcat() {
  echo "mdcat not found, installing the latest version..."

  # Get the latest release download URL for the Linux tarball (x86_64-unknown-linux-gnu)
  LATEST_URL=$(curl -s https://api.github.com/repos/swsnr/mdcat/releases/latest | jq -r ".assets[] | select(.name | test(\".*x86_64-unknown-linux-gnu.tar.gz$\")) | .browser_download_url")

  if [ -z "$LATEST_URL" ]; then
    echo "Error: Could not find the latest mdcat release URL."
    exit 1
  fi

  # Download the tarball
  echo "Downloading mdcat from $LATEST_URL..."
  wget --show-progress "$LATEST_URL" -O "$HOME/mdcat-latest.tar.gz"

  # Extract the tarball to a temporary directory
  TEMP_DIR=$(mktemp -d)
  echo "Extracting mdcat to $TEMP_DIR..."
  tar -xzf "$HOME/mdcat-latest.tar.gz" -C "$TEMP_DIR"

  # List extracted files to verify the binary location
  echo "Listing extracted files:"
  ls -l "$TEMP_DIR"

  # Check if mdcat binary exists in the extracted files
  if [ ! -f "$TEMP_DIR/mdcat-2.7.1-x86_64-unknown-linux-gnu/mdcat" ]; then
    echo "Error: Could not find 'mdcat' binary in the extracted files."
    exit 1
  fi

  # Move the mdcat binary to the desired location
  echo "Moving mdcat to $INSTALL_DIR..."
  mkdir -p "$INSTALL_DIR"
  mv "$TEMP_DIR/mdcat-2.7.1-x86_64-unknown-linux-gnu/mdcat" "$MD_CAT_BIN"

  # Move the README.md file to the same location with the new name
  echo "Moving README.md to $README_FILE..."
  mv "$TEMP_DIR/mdcat-2.7.1-x86_64-unknown-linux-gnu/README.md" "$README_FILE"

  # Cleanup
  rm -rf "$TEMP_DIR"
  rm "$HOME/mdcat-latest.tar.gz"

  echo "mdcat installation completed."
}

# Check if mdcat is already installed
if command -v mdcat &> /dev/null; then
  echo "mdcat is already installed."
else
  install_mdcat
fi

# Ensure the installation directory is on the PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo "Adding $INSTALL_DIR to PATH..."
  echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc"
  source "$HOME/.bashrc"
  echo "$INSTALL_DIR added to PATH."
fi

echo "Installation complete. You can now use mdcat."

