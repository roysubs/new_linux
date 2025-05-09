#!/bin/bash

# --- Configuration ---
GITHUB_REPO="gitleaks/gitleaks"
TARGET_OS="linux"
TARGET_ARCH="x64"
INSTALL_DIR="/usr/local/bin"
# Expected filename pattern in the release assets (adjust if naming changes)
FILENAME_PATTERN="gitleaks_.*_${TARGET_OS}_${TARGET_ARCH}.tar.gz"

# --- Error Handling and Cleanup ---

# Trap to clean up temporary directories on exit
cleanup() {
  if [[ -d "$TMP_DIR_DOWNLOAD" ]]; then
    echo "Cleaning up temporary download directory: $TMP_DIR_DOWNLOAD"
    rm -rf "$TMP_DIR_DOWNLOAD"
  fi
  if [[ -d "$TMP_DIR_EXTRACT" ]]; then
    echo "Cleaning up temporary extraction directory: $TMP_DIR_EXTRACT"
    rm -rf "$TMP_DIR_EXTRACT"
  fi
}

trap cleanup EXIT

# --- Check Dependencies ---
echo "Checking for required tools (curl, jq, tar, sudo)..."
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed. Please install it using your package manager."
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it using your package manager."
    exit 1
fi
if ! command -v tar &> /dev/null; then
    echo "Error: tar is not installed. Please install it using your package manager."
    exit 1
fi
if ! command -v sudo &> /dev/null; then
    echo "Error: sudo is not installed. This script requires sudo privileges to install to $INSTALL_DIR."
    exit 1
fi
echo "All required tools found."
echo ""

# --- Check Installed Version ---
INSTALLED_VERSION=""
if command -v gitleaks &> /dev/null; then
    echo "Gitleaks found in PATH."
    # Get installed version, handle potential 'v' prefix and trim whitespace
    INSTALLED_VERSION_FULL=$(gitleaks version 2>&1)
    INSTALLED_VERSION=$(echo "$INSTALLED_VERSION_FULL" | tr -d 'v' | xargs) # remove 'v' and trim whitespace
    echo "Installed version: $INSTALLED_VERSION_FULL ($INSTALLED_VERSION for comparison)"
else
    echo "Gitleaks not found in PATH. Proceeding with installation."
fi
echo ""

# --- Get Latest Release Information ---
echo "Fetching latest release information for $GITHUB_REPO..."
LATEST_RELEASE_INFO=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest")

# Extract latest version tag (remove 'v' prefix for comparison)
LATEST_VERSION_FULL=$(echo "$LATEST_RELEASE_INFO" | jq -r '.tag_name')
LATEST_VERSION=$(echo "$LATEST_VERSION_FULL" | tr -d 'v' | xargs) # remove 'v' and trim whitespace

# Extract the download URL for the target asset
DOWNLOAD_URL=$(echo "$LATEST_RELEASE_INFO" |
  jq -r ".assets[] | select(.name | match(\"$FILENAME_PATTERN\")) | .browser_download_url")

# Check if latest version and download URL were found
if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" == "null" ]; then
  echo "Error: Could not determine the latest release version from GitHub API."
  exit 1
fi
if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" == "null" ]; then
  echo "Error: Could not find the latest release binary download URL for ${TARGET_OS}/${TARGET_ARCH} matching pattern '$FILENAME_PATTERN'."
  echo "Please check the GitHub releases page manually: https://github.com/$GITHUB_REPO/releases"
  exit 1
fi

echo "Latest version available: $LATEST_VERSION_FULL ($LATEST_VERSION for comparison)"
echo "Download URL: $DOWNLOAD_URL"
echo ""

# --- Compare Versions and Decide Action ---
NEEDS_INSTALL=false

if [ -z "$INSTALLED_VERSION" ]; then
    # Gitleaks not installed, definitely need to install
    echo "Gitleaks is not installed. Proceeding to download the latest version."
    NEEDS_INSTALL=true
else
    # Gitleaks is installed, compare versions
    # Simple string comparison for version numbers like X.Y.Z should work
    # assuming standard semantic versioning without complex pre-release tags
    if [[ "$LATEST_VERSION" == "$INSTALLED_VERSION" ]]; then
        echo "You already have the latest version ($INSTALLED_VERSION_FULL). No installation needed."
        NEEDS_INSTALL=false
    elif [[ "$INSTALLED_VERSION" < "$LATEST_VERSION" ]]; then
        echo "A newer version ($LATEST_VERSION_FULL) is available. Proceeding to download."
        NEEDS_INSTALL=true
    else
        echo "Your installed version ($INSTALLED_VERSION_FULL) is newer or the same as the latest available. No installation needed."
        NEEDS_INSTALL=false
    fi
fi
echo ""

# --- Download, Extract, and Install (if needed) ---
if [ "$NEEDS_INSTALL" = true ]; then
    # Create a temporary directory for download
    TMP_DIR_DOWNLOAD=$(mktemp -d -t gitleaks_download_XXXXXXXXXX)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create temporary download directory."
        exit 1
    fi
    echo "Created temporary download directory: $TMP_DIR_DOWNLOAD"

    # Determine the filename from the URL
    FILENAME=$(basename "$DOWNLOAD_URL")
    DOWNLOAD_PATH="$TMP_DIR_DOWNLOAD/$FILENAME"

    echo "Downloading $FILENAME to $DOWNLOAD_PATH..."

    # Download the tar.gz file
    curl -L -o "$DOWNLOAD_PATH" "$DOWNLOAD_URL"

    # Check if download was successful
    if [ $? -ne 0 ]; then
      echo "Error: Failed to download the file."
      exit 1
    fi

    echo "Download complete. Extracting $FILENAME..."

    # Create a temporary directory for extraction
    TMP_DIR_EXTRACT=$(mktemp -d -t gitleaks_extract_XXXXXXXXXX)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create temporary extraction directory."
        exit 1
    fi
    echo "Created temporary extraction directory: $TMP_DIR_EXTRACT"

    # Extract the tar.gz file into the temporary extraction directory
    tar -xvzf "$DOWNLOAD_PATH" -C "$TMP_DIR_EXTRACT"

    # Find the extracted binary (usually named 'gitleaks')
    EXTRACTED_BINARY=""
    # Use find to locate an executable file that starts with 'gitleaks' inside the temp extract dir
    # This handles cases where the archive might have a subdirectory or different structure
    FOUND_BINARY_PATH=$(find "$TMP_DIR_EXTRACT" -type f -executable -name "gitleaks*" -print -quit)

    if [ -z "$FOUND_BINARY_PATH" ]; then
        echo "Error: Could not find the extracted gitleaks executable binary in $TMP_DIR_EXTRACT."
        echo "Please check the contents of the downloaded archive manually: tar -tf \"$DOWNLOAD_PATH\""
        exit 1
    else
        EXTRACTED_BINARY="$FOUND_BINARY_PATH"
        echo "Found extracted executable binary: $(basename "$EXTRACTED_BINARY")"
    fi

    # Check if the install directory exists, create if not (requires sudo)
    if [ ! -d "$INSTALL_DIR" ]; then
        echo "Install directory $INSTALL_DIR does not exist. Creating it with sudo..."
        sudo mkdir -p "$INSTALL_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create install directory $INSTALL_DIR with sudo."
            exit 1
        fi
    fi

    echo "Moving the binary to $INSTALL_DIR with sudo..."
    # Move the extracted binary to the install directory
    sudo mv "$EXTRACTED_BINARY" "$INSTALL_DIR/"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to move the binary to $INSTALL_DIR with sudo."
        exit 1
    fi

    echo "Installation complete. Gitleaks should now be available in your PATH."
    echo "You might need to open a new terminal session or run 'source ~/.bashrc' (or equivalent) for the changes to take effect."
    echo ""
    echo "Verify the installation:"
    gitleaks version

else
    echo "Gitleaks is already up-to-date or newer. No installation performed."
fi

exit 0
