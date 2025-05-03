#!/bin/bash

# --- Start mdcat Installation Logic (Terse) ---
# Define the location where mdcat will be installed
INSTALL_DIR="$HOME/.local/bin"

# Function to download and install mdcat
install_mdcat() {
    echo "mdcat not found, installing..."

    # Get the latest release download URL for the Linux tarball (x86_64-unknown-linux-gnu)
    LATEST_URL=$(curl -s https://api.github.com/repos/swsnr/mdcat/releases/latest | jq -r ".assets[] | select(.name | test(\".*x86_64-unknown-linux-gnu.tar.gz$\")) | .browser_download_url")

    if [ -z "$LATEST_URL" ]; then
        echo "Error: Could not find the latest mdcat release URL."
        exit 1
    fi

    # Download the tarball
    echo "Downloading mdcat..."
    wget -q --show-progress "$LATEST_URL" -O "$HOME/mdcat-latest.tar.gz"

    # Extract the tarball to a temporary directory
    TEMP_DIR=$(mktemp -d)
    # echo "Extracting mdcat to $TEMP_DIR..." # Removed for terseness
    tar -xzf "$HOME/mdcat-latest.tar.gz" -C "$TEMP_DIR"

    # Find the extracted mdcat binary and README.md
    # Using find to be more robust against versioned directory names in the tarball
    MD_CAT_BIN_SRC=$(find "$TEMP_DIR" -name "mdcat" -type f)
    README_FILE_SRC=$(find "$TEMP_DIR" -name "README.md" -type f)

    if [ -z "$MD_CAT_BIN_SRC" ]; then
        echo "Error: Could not find 'mdcat' binary in the extracted files."
        rm -rf "$TEMP_DIR"
        rm "$HOME/mdcat-latest.tar.gz"
        exit 1
    fi
     if [ -z "$README_FILE_SRC" ]; then
        echo "Warning: Could not find 'README.md' in the extracted files."
     fi

    # Move the mdcat binary and README to the desired location
    mkdir -p "$INSTALL_DIR"
    mv "$MD_CAT_BIN_SRC" "$INSTALL_DIR/mdcat"
    if [ -n "$README_FILE_SRC" ]; then
      mv "$README_FILE_SRC" "$INSTALL_DIR/mdcat-README.md" # Rename README for clarity
    fi

    # Cleanup
    rm -rf "$TEMP_DIR"
    rm "$HOME/mdcat-latest.tar.gz"

    echo "mdcat installed to '$INSTALL_DIR'."
}

# Check if mdcat is already installed
if ! command -v mdcat &> /dev/null; then
    # Check if jq, curl, wget, tar are available first
    if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null || ! command -v wget &> /dev/null || ! command -v tar &> /dev/null; then
        echo "Error: jq, curl, wget, or tar not found. Please install them first (e.g., sudo apt update && sudo apt install -y jq curl wget tar)."
        exit 1
    fi
    install_mdcat
else
    echo "mdcat is already installed."
fi

# Ensure the installation directory is on the PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo "Adding $INSTALL_DIR to PATH..."
    echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc"
    # Using exec bash to apply changes immediately without requiring manual re-source
    # This replaces the current shell process with a new one with the updated PATH
    echo "Please re-login or run 'source ~/.bashrc' in new terminals."
    # source "$HOME/.bashrc" # Removed source as it might not affect calling script
fi

# echo "Installation complete. You can now use mdcat." # Combined with later message
# --- End mdcat Installation Logic ---

echo # Add a newline for separation

# The following will operate on files that:
# - Have the name "h-*" in /usr/local/bin/
echo "Removing old h-* help files from /usr/local/bin/"
for file in /usr/local/bin/h-*; do
    # Only proceed if it's an actual file
    if [ -f "$file" ]; then
        echo "Remove: $file"
        sudo rm -f "$file"
    fi
done

echo # Add a newline for separation

# Ensure every ./0-help/h-* is chmod +x
echo "Making new h-* help files executable..."
for file in ~/new_linux/0-help/h-*; do
    if [ -f "$file" ]; then
        chmod +x "$file"
        # echo "Made executable: $file" # Removed for terseness
    fi
done

echo # Add a newline for separation

# Copy every ./0-help/h-* to /usr/local/bin
echo "Copying new h-* help files to /usr/local/bin/"
for file in ~/new_linux/0-help/h-*; do
    if [ -f "$file" ]; then
        echo "Add to PATH: $file"
        sudo cp -f "$file" /usr/local/bin/
    fi
done

echo
echo "Markdown help files installed to /usr/local/bin/ (which is in \$PATH)"
echo "Type h- then press Tab twice to see available markdown help files."
echo "Mdcat is installed and available (may require re-login or sourcing ~/.bashrc)."
echo

# We use /usr/local/bin becasue it is a standard directory used for user-installed executable programs.
# By convention, /usr/local/bin is used to store programs that the system administrator installs
# locally (manually) rather than through the package manager. This helps keep these programs separate
# from those installed by the system package manager. Also, it is a common location across almost all
# Linux distributions, so is a portable and consistent location for these help files.
# User Permissions: It provides a clear distinction between system-managed binaries in /usr/bin and
# /bin, and locally-managed binaries in /usr/local/bin. This ensures that local changes do not
# interfere with system-managed software.
