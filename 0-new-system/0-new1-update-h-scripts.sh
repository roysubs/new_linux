#!/bin/bash
# Refactored script to conditionally update mdcat and update h-* markdown help files with summary.

# Exit immediately if a command exits with a non-zero status.
# This prevents subsequent commands from running if a previous one fails.
set -e

# --- Configuration ---
MDCAT_INSTALL_DIR="$HOME/.local/bin"
DESTINATION_DIR="/usr/local/bin"
SOURCE_FILE_PATTERN="./h-*" # Look for h-* files in the current directory

# --- Function to install mdcat ---
# Downloads and installs the latest mdcat binary to $MDCAT_INSTALL_DIR.
# Assumes necessary tools (jq, curl, wget, tar) are available or checked before calling.
install_mdcat() {
    local latest_url="$1" # Pass the latest download URL as an argument

    echo "Starting mdcat installation..."

    LOCAL_TARBALL="$HOME/mdcat-latest.tar.gz"
    echo "Downloading mdcat from $latest_url..."
    wget -q --show-progress "$latest_url" -O "$LOCAL_TARBALL"

    TEMP_DIR=$(mktemp -d)
    echo "Extracting mdcat to $TEMP_DIR..."
    tar -xzf "$LOCAL_TARBALL" -C "$TEMP_DIR"

    # Find the extracted mdcat binary - looks for a file named 'mdcat' within the extracted temp dir
    MD_CAT_BIN_SRC=$(find "$TEMP_DIR" -name "mdcat" -type f)

    if [ -z "$MD_CAT_BIN_SRC" ]; then
        echo "Error: Could not find 'mdcat' binary in the extracted files."
        # Cleanup temporary files, ignore errors if files don't exist
        rm -rf "$TEMP_DIR" || true
        rm "$LOCAL_TARBALL" || true
        return 1 # Indicate failure
    else
        # Ensure install directory exists in user's home
        mkdir -p "$MDCAT_INSTALL_DIR"

        # Move the mdcat binary to the installation directory
        echo "Installing mdcat binary to '$MDCAT_INSTALL_DIR'..."
        mv "$MD_CAT_BIN_SRC" "$MDCAT_INSTALL_DIR/mdcat"
        chmod +x "$MDCAT_INSTALL_DIR/mdcat" # Ensure it's executable

        # Optional: Find and move README if desired
        # README_FILE_SRC=$(find "$TEMP_DIR" -name "README.md" -type f)
        # if [ -n "$README_FILE_SRC" ]; then
        #     mv "$README_FILE_SRC" "$MDCAT_INSTALL_DIR/mdcat-README.md" # Rename README for clarity
        # fi

        # Cleanup temporary files, ignore errors if files don't exist
        rm -rf "$TEMP_DIR" || true
        rm "$LOCAL_TARBALL" || true

        echo "mdcat successfully installed to '$MDCAT_INSTALL_DIR'."

        # Add install directory to PATH if not already there (for future sessions)
        if ! echo "$PATH" | grep -q "$MDCAT_INSTALL_DIR"; then
             echo "Adding $MDCAT_INSTALL_DIR to PATH in ~/.bashrc..."
             # Ensure the export line is not added multiple times
             if ! grep -q "export PATH=.*$MDCAT_INSTALL_DIR" "$HOME/.bashrc"; then
                 echo "export PATH=\"$MDCAT_INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc"
             fi
             echo "Please re-login or run 'source ~/.bashrc' in new terminals to update PATH."
        fi
        return 0 # Indicate success
    fi
}

# --- Check for necessary tools ---
# jq, curl, wget, tar are needed for mdcat installation/version check
if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null || ! command -v wget &> /dev/null || ! command -v tar &> /dev/null; then
    echo "Warning: Required tools (jq, curl, wget, tar) for mdcat installation/update not found."
    echo "mdcat installation/update will be skipped. Please install them first (e.g., sudo apt update && sudo apt install -y jq curl wget tar)."
    MDCAT_DEPS_MISSING=true
else
    MDCAT_DEPS_MISSING=false
fi


# --- Check and Update mdcat if needed ---
if [ "$MDCAT_DEPS_MISSING" = false ]; then
    if command -v mdcat &> /dev/null; then
        # Try to extract version number using grep -oP (Perl-compatible regex for \d)
        # Look for a pattern like v?X.Y.Z where X, Y, Z are numbers.
        # Take only the first match found.
        INSTALLED_VERSION=$(mdcat --version 2>&1 | grep -oP 'v?\d+(\.\d+)*' | head -n 1)

        if [ -z "$INSTALLED_VERSION" ]; then
            echo "Warning: Could not automatically determine installed mdcat version from 'mdcat --version' output."
            echo "The output was:"
            mdcat --version 2>&1 | sed 's/^/  /' # Indent the output for clarity
            echo "Skipping automatic mdcat version check and update."
        else
            echo "Found installed mdcat version: $INSTALLED_VERSION"

            echo "Checking for latest mdcat release from GitHub..."
            # Get latest release info (tag_name and download URL)
            LATEST_RELEASE_INFO=$(curl -s https://api.github.com/repos/swsnr/mdcat/releases/latest)
            LATEST_VERSION_TAG=$(echo "$LATEST_RELEASE_INFO" | jq -r ".tag_name")
             # Ensure LATEST_VERSION_TAG is also just the version number for comparison if it has a 'v' prefix
            LATEST_VERSION_COMPARE=$(echo "$LATEST_VERSION_TAG" | sed 's/^v//')

            LATEST_URL=$(echo "$LATEST_RELEASE_INFO" | jq -r ".assets[] | select(.name | test(\".*x86_64-unknown-linux-gnu.tar.gz$\")) | .browser_download_url")

            if [ -z "$LATEST_VERSION_TAG" ] || [ -z "$LATEST_URL" ]; then
                 echo "Error: Could not fetch latest mdcat release info from GitHub."
                 echo "Skipping mdcat update."
            else
                echo "Latest mdcat version available: $LATEST_VERSION_TAG"

                # Compare versions using sort -V (handles semantic versioning)
                # Ensure both versions for comparison are just numbers.dots (remove leading 'v')
                INSTALLED_VERSION_COMPARE=$(echo "$INSTALLED_VERSION" | sed 's/^v//')

                # Use sort -V to find the highest version.
                # If the highest version is the latest version tag (after removing 'v'),
                # and it's different from the installed version (after removing 'v'), then update.

                HIGHEST_VERSION=$(printf "%s\n%s" "$INSTALLED_VERSION_COMPARE" "$LATEST_VERSION_COMPARE" | sort -V | tail -n 1)

                if [ "$HIGHEST_VERSION" = "$LATEST_VERSION_COMPARE" ] && [ "$INSTALLED_VERSION_COMPARE" != "$LATEST_VERSION_COMPARE" ]; then
                    echo "Installed version ($INSTALLED_VERSION) is older than the latest ($LATEST_VERSION_TAG)."
                    install_mdcat "$LATEST_URL" || echo "mdcat update failed."
                else
                    echo "mdcat is already up-to-date (version $INSTALLED_VERSION)."
                fi
            fi
        fi
    else
        # mdcat not found, proceed with installation
        echo "mdcat not found. Proceeding with installation."

        # Need to fetch latest info here too to get the download URL
        LATEST_RELEASE_INFO=$(curl -s https://api.github.com/repos/swsnr/mdcat/releases/latest)
        LATEST_URL=$(echo "$LATEST_RELEASE_INFO" | jq -r ".assets[] | select(.name | test(\".*x86_64-unknown-linux-gnu.tar.gz$\")) | .browser_download_url")

         if [ -z "$LATEST_URL" ]; then
             echo "Error: Could not fetch latest mdcat download URL from GitHub."
             echo "mdcat installation skipped."
         else
             install_mdcat "$LATEST_URL" || echo "mdcat installation failed."
         fi
    fi
else
    echo "Skipping mdcat check/installation/update due to missing dependencies."
fi


echo # Add a newline for separation

# --- Update h-* markdown help files ---
# This section finds files in the current directory matching "h-*",
# checks if they are regular files and contain the text "mdcat",
# makes them executable, and copies them to the destination directory.

echo "Searching for '$SOURCE_FILE_PATTERN' files containing 'mdcat' in the current directory ($PWD)..."
echo "Filtered files will be copied to '$DESTINATION_DIR' (requires sudo)."

# Ensure the destination directory exists, requires sudo as it's typically a system directory
sudo mkdir -p "$DESTINATION_DIR"

# Initialize counter for copied files
COPIED_COUNT=0

# Loop through files matching the pattern in the current directory.
# Using a robust read loop with find to handle filenames with spaces or special characters.
find . -maxdepth 1 -type f -name "h-*" | while IFS= read -r file; do
    # Check if the file contains the text 'mdcat'
    # '-q' makes grep silent, just returning success/fail exit status
    if grep -q 'mdcat' "$file"; then
        echo "Processing: '$file'"

        # Make the source file executable before copying
        chmod +x "$file"

        # Copy the executable file to the destination, overwriting if it exists ('-f')
        # Requires sudo as the destination is a system directory
        if sudo cp -f "$file" "$DESTINATION_DIR/"; then
            # echo "Copied '$file' to '$DESTINATION_DIR/'." # Keep terser, only echo Processing
            ((COPIED_COUNT++)) # Increment counter only on successful copy
        else
            echo "Error: Failed to copy '$file' to '$DESTINATION_DIR/'."
        fi
    # else
        # Optional: uncomment the line below if you want to see which files are skipped by the grep test
        # echo "Skipping '$file': does not contain 'mdcat'."
    fi
done

echo
echo "--- Summary ---"
echo "Markdown help files processed."
echo "Copied $COPIED_COUNT h-* files containing 'mdcat' to '$DESTINATION_DIR'."
# mdcat status message is now handled by the specific check/update logic
if [ "$MDCAT_DEPS_MISSING" = true ]; then
    echo "mdcat check/update skipped due to missing dependencies."
fi
echo

# Explanation for /usr/local/bin
echo "Note: Files are installed to $DESTINATION_DIR."
echo "This is a standard location for user-installed executables, keeping them separate"
echo "from system packages and typically already in the system's PATH."
