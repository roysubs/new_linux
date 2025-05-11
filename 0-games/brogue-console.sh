#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

REPO="tmewett/BrogueCE"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

echo "BrogueCE Terminal Build and Install Script"
echo "=========================================="
echo "This script will download the latest source code for BrogueCE,"
echo "configure it for terminal play, compile it, and install it"
echo "in your home directory (~/.local/...) with a 'brogue-console' command."
echo

# --- Prerequisites Check ---
echo "Checking for required tools..."
REQUIRED_COMMANDS="curl jq make gcc tar sed tput"
MISSING_COMMANDS=""

for cmd in $REQUIRED_COMMANDS; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "  '$cmd' NOT found."
        MISSING_COMMANDS="$MISSING_COMMANDS $cmd"
    else
        echo "  '$cmd' found."
    fi
done

if [ -n "$MISSING_COMMANDS" ]; then
    echo
    echo "Error: The following required commands were not found: $MISSING_COMMANDS"
    echo "Please install them using your distribution's package manager:"
    echo "For Debian/Ubuntu: sudo apt update && sudo apt install build-essential curl jq"
    echo "For Fedora/RHEL: sudo dnf install curl jq make gcc tar sed ncurses"
    echo "For Arch Linux: sudo pacman -S base-devel curl jq"
    exit 1
fi

echo "Checking for build dependencies (like ncurses development headers)..."
# Try to detect ncurses development package
if ! pkg-config --exists ncurses 2>/dev/null && ! [ -f "/usr/include/ncurses.h" ] && ! [ -f "/usr/include/ncurses/ncurses.h" ]; then
    echo "Warning: Could not detect ncurses development headers."
    echo "Compilation will likely fail without development libraries such as 'libncurses-dev' (Debian/Ubuntu) or 'ncurses-devel' (Fedora/RHEL/Arch)."
    echo "Please install them before running the script if you encounter errors during compilation:"
    echo "For Debian/Ubuntu: sudo apt install build-essential libncurses-dev"
    echo "For Fedora/RHEL: sudo dnf groupinstall 'Development Tools' 'C Development Tools and Libraries' && sudo dnf install ncurses-devel"
    echo "For Arch Linux: sudo pacman -S base-devel ncurses"
    echo
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation aborted."
        exit 1
    fi
else
    echo "Ncurses development headers appear to be installed."
fi
echo

# Create and use temporary directory for downloads and builds
TEMP_DIR=$(mktemp -d)
echo "Using temporary directory for downloads and build: $TEMP_DIR"
cd "$TEMP_DIR" || { echo "Error: Failed to change to temporary directory"; exit 1; }

trap cleanup EXIT
cleanup() {
    echo "Cleaning up temporary files..."
    cd "$SCRIPT_DIR" || true
    rm -rf "$TEMP_DIR"
    echo "Cleanup complete."
}

# Save the directory where the script was run from
SCRIPT_DIR="$PWD"

# --- Find Latest Release ---
echo "Finding the latest release for ${REPO}..."
RELEASE_INFO=$(curl -s "$API_URL")

# Extract tag name and tarball URL using jq
TAG_NAME=$(echo "$RELEASE_INFO" | jq -r '.tag_name')
TARBALL_URL=$(echo "$RELEASE_INFO" | jq -r '.tarball_url')

if [ -z "$TAG_NAME" ] || [ "$TAG_NAME" == "null" ]; then
    echo "Error: Could not retrieve latest release tag name from the GitHub API."
    echo "API Response: $RELEASE_INFO"
    exit 1
fi

if [ -z "$TARBALL_URL" ] || [ "$TARBALL_URL" == "null" ]; then
     echo "Error: Could not retrieve tarball URL from the GitHub API."
     echo "API Response: $RELEASE_INFO"
     exit 1
fi

echo "Found latest version: $TAG_NAME"
echo "Download URL: $TARBALL_URL"
echo

# --- Download Source Code ---
echo "Downloading source code archive from '$TARBALL_URL'..."
curl -LJO "$TARBALL_URL"

# --- Find the downloaded file ---
sleep 1 # Give filesystem a moment to update timestamp
DOWNLOADED_FILE=$(ls -t *.tar.gz 2>/dev/null | head -n 1)

if [ -z "$DOWNLOADED_FILE" ] || [ ! -f "$DOWNLOADED_FILE" ]; then
    echo "Error: Download failed or no .tar.gz file was found in the current directory after download."
    echo "Please check the curl output above for errors."
    exit 1
fi
FILENAME="$DOWNLOADED_FILE"
echo "Downloaded archive: '$FILENAME'."
echo

# --- Extract Source Code ---
echo "Extracting source code from '$FILENAME'..."
EXTRACTED_DIR_NAME=$(tar -tf "$FILENAME" | head -n 1 | cut -d'/' -f1)

if [ -z "$EXTRACTED_DIR_NAME" ]; then
    echo "Error: Could not determine the top-level directory name from the archive '$FILENAME'."
    echo "Archive contents seem unexpected."
    exit 1
fi

DIR_NAME="$EXTRACTED_DIR_NAME" # Set DIR_NAME to the actual extracted directory name

if [ -d "$DIR_NAME" ]; then
    echo "Warning: Directory '$DIR_NAME' already exists. Removing it before extraction."
    rm -rf "$DIR_NAME"
fi

tar -xzf "$FILENAME"

if [ ! -d "$DIR_NAME" ]; then
     echo "Error: Extraction failed. Expected directory '$DIR_NAME' not found after extraction."
     echo "Please check the tar output above for errors."
     exit 1
fi
echo "Extracted to '$DIR_NAME'."
echo

# --- Configure for Terminal ---
echo "Navigating into '$DIR_NAME' and configuring for terminal support..."
cd "$DIR_NAME" || { echo "Error: Failed to change directory to '$DIR_NAME'"; exit 1; }

if [ ! -f "config.mk" ]; then
    echo "Error: config.mk not found in '$DIR_NAME'. Cannot configure."
    exit 1
fi

cp config.mk config.mk.bak
echo "Backed up config.mk to config.mk.bak"

# --- Simplified modification logic for config.mk (Corrected for :=) ---
echo "Attempting to set TERMINAL := YES in config.mk..."

if grep -q '^TERMINAL :=' config.mk; then
    sed -i 's/^TERMINAL := .*$/TERMINAL := YES/' config.mk
    echo "Replaced existing 'TERMINAL :=' line with 'TERMINAL := YES'."
else
    echo "Error: No line starting with 'TERMINAL :=' found in config.mk."
    echo "Cannot automatically configure for terminal support."
    echo "Please check the BrogueCE release documentation or config.mk for the correct setting."
    exit 1
fi

if grep -q '^TERMINAL := YES' config.mk; then
    echo "Successfully set TERMINAL := YES in config.mk for terminal build."
else
    echo "Error: Verification failed. 'TERMINAL := YES' is not present in config.mk after attempted modification."
    echo "Please manually inspect '$DIR_NAME/config.mk' to understand why."
    exit 1
fi
echo

# --- Compile ---
echo "Compiling BrogueCE..."
make -B

if [ ! -f "brogue" ]; then
    echo "Error: Compilation failed. Executable 'brogue' not found in '$DIR_NAME'."
    echo "Check the output above for compiler errors."
    echo "You might be missing necessary build dependencies (like ncurses development headers)."
    exit 1
fi
echo "Compilation successful! The executable is './brogue' inside '$DIR_NAME'."
echo

# --- Verification of Compiled Binary ---
echo "Verifying compiled 'brogue' file in build directory..."
# Check if it's executable and appears to be a binary (not a script)
if [ ! -x "brogue" ] || file brogue | grep -q "script"; then
    echo "Error: The compiled 'brogue' file in '$DIR_NAME' is not a binary executable or appears to be a script."
    echo "This is unexpected after a successful 'make'."
    echo "File type information: $(file brogue)"
    echo "First 10 lines of 'brogue' in build directory:"
    head -n 10 brogue
    exit 1 # Abort installation if the source binary is not valid
fi
echo "Verification successful: 'brogue' in build directory is a valid executable binary."
echo
# --- End Verification ---


# --- Installation ---
INSTALL_BASE="$HOME/.local"
INSTALL_DIR="$INSTALL_BASE/share/games/brogue-ce-terminal"
BIN_DIR="$INSTALL_BASE/bin"
WRAPPER_SCRIPT_PATH="$BIN_DIR/brogue-console"

echo "Installing BrogueCE to '$INSTALL_DIR' and creating wrapper script '$WRAPPER_SCRIPT_PATH'..."

mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"
echo "Created installation directory '$INSTALL_DIR' and binary directory '$BIN_DIR'."

FILES_TO_COPY=("brogue" "unicode_maps.txt" "scores.txt" "scores/" "licenses/" "README.md")

echo "Copying compiled executable and data files to '$INSTALL_DIR'..."
for item in "${FILES_TO_COPY[@]}"; do
    if [ -e "$item" ]; then
        if [ -d "$item" ]; then
            echo "  Copying directory '$item'..."
            rsync -a "$item" "$INSTALL_DIR/"
        else
            echo "  Copying file '$item'..."
            cp "$item" "$INSTALL_DIR/"
        fi
    elif [[ "$item" == "scores/" ]]; then
         echo "  Warning: Optional directory '$item' not found in the build directory. It will be created on first run."
    else
        echo "  Warning: Source item '$item' not found in the build directory. It might be missing or not required."
    fi
done
echo "Finished copying files."

# --- Create Wrapper Script ---
echo "Creating wrapper script '$WRAPPER_SCRIPT_PATH'..."

cat << EOF > "$WRAPPER_SCRIPT_PATH"
#!/bin/bash

# This script wraps the BrogueCE executable to perform pre-launch checks.

# Path to the actual BrogueCE installation directory
GAME_DIR="$INSTALL_DIR"
GAME_EXEC="brogue" # The name of the executable file in GAME_DIR

# Required terminal dimensions
REQUIRED_WIDTH=100
REQUIRED_HEIGHT=34

# Check if tput is available
if ! command -v tput &> /dev/null; then
    echo "Error: 'tput' command not found." >&2
    echo "Cannot check terminal size. Please install it (e.g., sudo apt install ncurses-bin)." >&2
    exit 1
fi

# Get current terminal size
CURRENT_WIDTH=\$(tput cols)
CURRENT_HEIGHT=\$(tput lines)

# Check if size is sufficient
if [ "\$CURRENT_WIDTH" -lt "\$REQUIRED_WIDTH" ] || [ "\$CURRENT_HEIGHT" -lt "\$REQUIRED_HEIGHT" ]; then
    echo "BrogueCE requires a terminal window of at least \${REQUIRED_WIDTH}x\${REQUIRED_HEIGHT} characters."
    echo "Your current terminal size is \${CURRENT_WIDTH}x\${CURRENT_HEIGHT}."
    echo "Please resize your terminal and try again."
    echo "Press Enter to exit."
    read -r # Wait for user input before exiting
    exit 1
fi

# If size is sufficient, navigate to the game directory and run the executable
echo "Terminal size is sufficient (\${CURRENT_WIDTH}x\${CURRENT_HEIGHT}). Launching BrogueCE..."
# Change to the game's directory first so it can find its data files
cd "\$GAME_DIR" || { echo "Error: Could not change directory to \$GAME_DIR" >&2; exit 1; }

# --- DEBUGGING START ---
# These lines should ONLY print if 'exec' fails for some reason.
# If you see these lines followed by the loop, it indicates exec failed and control returned.
echo "DEBUG: Attempting to execute: \$PWD/\$GAME_EXEC -t" >&2
echo "DEBUG: Current directory (PWD) is: \$PWD" >&2
if [ ! -f "./\$GAME_EXEC" ]; then
    echo "DEBUG: Error: Executable file './\$GAME_EXEC' does not exist in the current directory (\$PWD)." >&2
    ls -l ./ >&2 # List contents of current directory
elif [ ! -x "./\$GAME_EXEC" ]; then
     echo "DEBUG: Error: Executable file './\$GAME_EXEC' exists but does not have execute permission." >&2
     ls -l "./\$GAME_EXEC" >&2 # Show permissions
fi
# --- DEBUGGING END ---

# Execute the game, replacing the current shell process, ONLY passing -t
# The shell process should be replaced by the Brogue process here.
exec "./\$GAME_EXEC" -t

# If the script reaches here, 'exec' failed.
echo "Error: Failed to execute BrogueCE binary at \$GAME_DIR/\$GAME_EXEC." >&2
exit 1 # Exit the script after failure
EOF

chmod +x "$WRAPPER_SCRIPT_PATH"
echo "Created and made executable: '$WRAPPER_SCRIPT_PATH'."
echo

# --- Final Instructions ---
echo "BrogueCE Terminal version has been successfully installed."
echo "Installation directory: $INSTALL_DIR"
echo "Wrapper command: brogue-console"
echo
echo "To run the game:"
echo "1. Open a new terminal or refresh your shell environment (e.g., log out/in, or 'source ~/.bashrc'/'source ~/.zshrc')."
echo "   This ensures that '$BIN_DIR' (i.e., '$HOME/.local/bin') is in your system's PATH."
echo "2. Type the command:"
echo "   brogue-console"
echo
echo "The script will check your terminal size and launch the game if it meets the minimum requirement (100x34)."
echo "If the command 'brogue-console' is not found, confirm that '$BIN_DIR' is in your PATH."
echo "If you encounter issues launching the game (like the infinite loop), please report any 'DEBUG:' output lines that appear."
echo "Also, try running the executable directly from the installation directory: cd '$INSTALL_DIR' && ./brogue -t"
echo

echo "Script finished."
