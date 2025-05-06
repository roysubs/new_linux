#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "Starting yq installation script (mikefarah/yq version)..."

# --- Check and Uninstall APT yq ---
echo "Checking for apt package 'yq'..."
if dpkg -s yq &>/dev/null; then
    echo "Found apt package 'yq'. Uninstalling it..."
    # Use --purge to remove configuration files as well
    # Use -y to automatically confirm the removal
    sudo apt remove --purge -y yq
    echo "Apt package 'yq' uninstalled."
else
    echo "Apt package 'yq' not found or not installed. No action needed."
fi

# --- Ensure jq is installed (needed to get the latest release tag) ---
# We use jq to parse the JSON response from the GitHub API.
if ! command -v jq &> /dev/null; then
    echo "jq command not found. It's required to find the latest yq release from GitHub."
    echo "Attempting to install jq using apt..."
    sudo apt update
    sudo apt install -y jq
    if ! command -v jq &> /dev/null; then
        echo "Error: Failed to install jq. Please install jq manually and run the script again."
        echo "e.g., sudo apt install jq"
        exit 1
    fi
    echo "jq installed successfully."
else
    echo "jq is already installed."
fi

# --- Get the latest release version from GitHub ---
echo "Finding the latest yq release on GitHub (mikefarah/yq)..."
# Use curl to fetch the latest release info from the GitHub API
# Use jq to parse the JSON and extract the tag_name
LATEST_TAG=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r .tag_name)

if [ -z "$LATEST_TAG" ]; then
    echo "Error: Could not retrieve the latest yq version tag from GitHub API."
    exit 1
fi

echo "Latest version found: $LATEST_TAG"

# --- Determine system architecture ---
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        YQ_ARCH="amd64"
        ;;
    aarch64)
        YQ_ARCH="arm64"
        ;;
    armv7l|armhf) # Covers common 32-bit ARM variants
        YQ_ARCH="arm"
        ;;
    i386|i686)
        YQ_ARCH="386"
        ;;
    *)
        echo "Error: Unsupported architecture detected: $ARCH"
        echo "Cannot determine which yq binary to download. Exiting."
        exit 1
        ;;
esac

echo "Detected architecture: $ARCH, corresponding yq binary architecture: linux_$YQ_ARCH"

# --- Construct the download URL ---
DOWNLOAD_URL="https://github.com/mikefarah/yq/releases/download/$LATEST_TAG/yq_linux_$YQ_ARCH"
TEMP_YQ_PATH="/tmp/yq_temp_$RANDOM" # Use a random name for the temp file

echo "Downloading yq binary from $DOWNLOAD_URL"
# Use curl -L to follow redirects, -o to specify output file
if ! curl -L -o "$TEMP_YQ_PATH" "$DOWNLOAD_URL"; then
    echo "Error: Failed to download yq from $DOWNLOAD_URL"
    rm -f "$TEMP_YQ_PATH" # Clean up temporary file
    exit 1
fi

# --- Install the downloaded binary ---
echo "Making the downloaded binary executable..."
chmod +x "$TEMP_YQ_PATH"

INSTALL_PATH="/usr/local/bin/yq"
echo "Installing yq to $INSTALL_PATH (requires sudo)..."
# Move the temporary file to the installation path using sudo
sudo mv "$TEMP_YQ_PATH" "$INSTALL_PATH"

# --- Verify installation ---
echo "Verifying installed yq version..."
# Check if the command is in PATH and run the version check
if command -v yq &> /dev/null; then
    INSTALLED_VERSION=$(yq --version)
    # Check if the output contains "version" which is characteristic of mikefarah/yq
    if echo "$INSTALLED_VERSION" | grep -q 'version '; then
        echo "yq installed successfully!"
        echo "Installed version: $INSTALLED_VERSION"
    else
         echo "Error: yq command found, but version output is unexpected. It might not be the correct yq."
         echo "Output: $INSTALLED_VERSION"
         exit 1
    fi
else
    echo "Error: yq command not found in PATH after installation. Installation may have failed."
    exit 1
fi

echo "yq installation process completed."
