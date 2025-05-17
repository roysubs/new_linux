#!/bin/bash

# Define the location where mdcat will be installed
INSTALL_DIR="$HOME/.local/bin"
MD_CAT_BIN="$INSTALL_DIR/mdcat"
README_FILE="$INSTALL_DIR/mdcat-README.md"

# Function to install jq if not present
ensure_jq_installed() {
  if ! command -v jq &> /dev/null; then
    echo "jq not found, attempting to install it..."
    if   command -v apt &> /dev/null;    then sudo apt update && sudo apt install -y jq
    elif command -v yum &> /dev/null;    then sudo yum install -y jq
    elif command -v dnf &> /dev/null;    then sudo dnf install -y jq
    elif command -v pacman &> /dev/null; then sudo pacman -Syu --noconfirm jq
    elif command -v zypper &> /dev/null; then sudo zypper install -y jq
    else
      echo "Error: Could not find a known package manager (apt, yum, dnf, pacman, zypper) to install jq."
      echo "Please install jq manually and re-run the script."
      exit 1
    fi
    if ! command -v jq &> /dev/null; then
      echo "Error: jq installation failed or was not found after attempting installation."
      echo "Please install jq manually and re-run the script."
      exit 1
    fi
    echo "jq installed successfully."
  else
    echo "jq is already installed."
  fi
}

# Function to download and install mdcat
install_mdcat() {
  echo "mdcat not found, installing the latest version..."

  # Ensure jq is available
  ensure_jq_installed

  # Get the latest release download URL for the Linux tarball (x86_64-unknown-linux-gnu)
  echo "Fetching the latest mdcat release URL..."
  LATEST_URL=$(curl -s https://api.github.com/repos/swsnr/mdcat/releases/latest | jq -r ".assets[] | select(.name | test(\".*x86_64-unknown-linux-gnu.tar.gz$\")) | .browser_download_url")

  if [ -z "$LATEST_URL" ]; then
    echo "Error: Could not find the latest mdcat release URL. This might be due to rate limiting by GitHub API or jq parsing issues."
    echo "You can try again later or manually download from https://github.com/swsnr/mdcat/releases"
    exit 1
  fi

  # Download the tarball
  echo "Downloading mdcat from $LATEST_URL..."
  wget --show-progress "$LATEST_URL" -O "$HOME/mdcat-latest.tar.gz"

  # Extract the tarball to a temporary directory
  TEMP_DIR=$(mktemp -d)
  echo "Extracting mdcat to $TEMP_DIR..."
  tar -xzf "$HOME/mdcat-latest.tar.gz" -C "$TEMP_DIR"

  # Dynamically find the extracted directory name as it includes the version
  # Assuming there's only one directory created inside TEMP_DIR by the tar command
  EXTRACTED_DIR_NAME=$(ls "$TEMP_DIR" | head -n 1)
  if [ -z "$EXTRACTED_DIR_NAME" ] || [ ! -d "$TEMP_DIR/$EXTRACTED_DIR_NAME" ]; then
    echo "Error: Could not determine the extracted directory name."
    ls -l "$TEMP_DIR" # List content for debugging
    exit 1
  fi
  echo "Extracted directory found: $EXTRACTED_DIR_NAME"

  # Check if mdcat binary exists in the extracted files
  if [ ! -f "$TEMP_DIR/$EXTRACTED_DIR_NAME/mdcat" ]; then
    echo "Error: Could not find 'mdcat' binary in the extracted files at $TEMP_DIR/$EXTRACTED_DIR_NAME/mdcat."
    echo "Listing extracted files in $TEMP_DIR/$EXTRACTED_DIR_NAME:"
    ls -l "$TEMP_DIR/$EXTRACTED_DIR_NAME"
    exit 1
  fi

  # Move the mdcat binary to the desired location
  echo "Moving mdcat to $INSTALL_DIR..."
  mkdir -p "$INSTALL_DIR"
  mv "$TEMP_DIR/$EXTRACTED_DIR_NAME/mdcat" "$MD_CAT_BIN"

  # Move the README.md file to the same location with the new name
  echo "Moving README.md to $README_FILE..."
  if [ -f "$TEMP_DIR/$EXTRACTED_DIR_NAME/README.md" ]; then
    mv "$TEMP_DIR/$EXTRACTED_DIR_NAME/README.md" "$README_FILE"
  else
    echo "Warning: README.md not found in the archive. Skipping."
  fi

  # Cleanup
  rm -rf "$TEMP_DIR"
  rm "$HOME/mdcat-latest.tar.gz"

  echo "mdcat installation completed."
}

# --- Main script execution ---

# First, ensure jq is installed as it's needed by install_mdcat
ensure_jq_installed

# Check if mdcat is already installed
if command -v mdcat &> /dev/null && [ -f "$MD_CAT_BIN" ]; then
  echo "mdcat is already installed at $MD_CAT_BIN."
  # Optionally, you could add a check for updates here
else
  if [ -f "$MD_CAT_BIN" ]; then
    echo "mdcat binary found at $MD_CAT_BIN, but not in PATH or 'command -v' failed. Checking PATH..."
  else
    echo "mdcat not found by 'command -v' or at $MD_CAT_BIN."
  fi
  install_mdcat
fi

# Ensure the installation directory is on the PATH
if ! echo "$PATH" | grep -qF "$INSTALL_DIR"; then
  echo "Adding $INSTALL_DIR to PATH for the current session and .bashrc..."
  export PATH="$INSTALL_DIR:$PATH" # Add for current session
  # Check if .bashrc already contains the PATH modification
  if ! grep -qF "export PATH=\"$INSTALL_DIR:\$PATH\"" "$HOME/.bashrc"; then
    echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc"
    echo "$INSTALL_DIR added to PATH in .bashrc. Please source it or open a new terminal."
  else
    echo "$INSTALL_DIR is already configured in .bashrc PATH."
  fi
else
  echo "$INSTALL_DIR is already in your PATH."
fi

echo "Script finished. You can now use mdcat."
echo "If you opened a new terminal or sourced your .bashrc, mdcat should be available."
echo "Try: mdcat --version"
