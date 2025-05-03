#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define installation directories
INSTALL_SHARE_DIR="$HOME/.local/share/brogue-ce"
INSTALL_BIN_DIR="$HOME/.local/bin"
BROGUE_WRAPPER_SCRIPT="$INSTALL_BIN_DIR/brogue"
BROGUE_EXECUTABLE_IN_SHARE="$INSTALL_SHARE_DIR/bin/brogue"
BROGUE_ASSET_DIR_IN_SHARE="$INSTALL_SHARE_DIR/assets"

# --- Helper Functions ---

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        echo "$DISTRIB_ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/fedora-release ]; then
        echo "fedora"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    elif [ -f /etc/SuSE-release ]; then
        echo "opensuse"
    else
        echo "unknown"
    fi
}

# Function to install packages based on distribution
# Args: package_name1 package_name2 ...
install_package() {
    local distro=$(detect_distro)
    local packages="$@"

    echo "Attempting to install packages: $packages"

    case "$distro" in
        ubuntu|debian)
            if ! sudo apt update; then
                echo "Error: Failed to update apt repositories."
                exit 1
            fi
            if ! sudo apt install -y $packages; then
                echo "Error: Failed to install packages via apt: $packages"
                exit 1
            fi
            ;;
        fedora|rhel|centos|rocky|almalinux)
            if ! sudo dnf install -y $packages; then
                 echo "Error: Failed to install packages via dnf: $packages"
                 exit 1
            fi
            ;;
        arch)
             if ! sudo pacman -Sy --noconfirm $packages; then
                 echo "Error: Failed to install packages via pacman: $packages"
                 exit 1
             fi
            ;;
        opensuse)
            if ! sudo zypper install -y $packages; then
                 echo "Error: Failed to install packages via zypper: $packages"
                 exit 1
            fi
            ;;
        *)
            echo "Error: Unsupported distribution '$distro'. Please install '$packages' manually."
            exit 1
            ;;
    esac
}

# Function to check and install dependencies (basic tools and SDL2_image)
check_and_install_dependencies() {
    echo "Checking for required system dependencies..."

    local missing_tools=""
    command -v curl &> /dev/null || missing_tools+=" curl"
    command -v jq &> /dev/null || missing_tools+=" jq"
    command -v tar &> /dev/null || missing_tools+=" tar"

    if [ -n "$missing_tools" ]; then
        echo "Missing required tools:$missing_tools"
        install_package $missing_tools
    else
        echo "Required tools (curl, jq, tar) are installed."
    fi

    # Check and install SDL2_image library
    local sdl_package=""
    local distro=$(detect_distro)
    case "$distro" in
        ubuntu|debian) sdl_package="libsdl2-image-2.0-0";;
        fedora|rhel|centos|rocky|almalinux) sdl_package="SDL2_image";;
        arch) sdl_package="sdl2_image";;
        opensuse) sdl_package="libSDL2_image-2_0-0";;
        *)
            echo "Warning: Skipping automatic SDL2_image installation for unsupported distribution '$distro'. Please install it manually."
            # Continue script execution even if SDL install skipped, user might have it already
            return
            ;;
    esac

    # Check if the SDL2_image library file exists before trying to install
    # This check uses common locations and dpkg/rpm/pacman queries.
    if ! dpkg -S libSDL2_image-2.0.so.0 &> /dev/null && \
       ! rpm -q --whatprovides libSDL2_image-2.0.so.0 &> /dev/null && \
       ! pacman -Qo /usr/lib/libSDL2_image-2.0.so.0 &> /dev/null && \
       ! test -f /usr/lib/libSDL2_image-2.0.so.0 && \
       ! test -f /usr/lib64/libSDL2_image-2.0.so.0; then
        echo "SDL2_image library not found. Installing '$sdl_package'..."
        install_package "$sdl_package"
    else
        echo "SDL2_image library appears to be installed."
    fi
}


# Function to download, extract, and set up BrogueCE
setup_brogue_installation() {
    echo "Setting up BrogueCE installation..."

    # --- Cleanup Previous Installation ---
    if [ -d "$INSTALL_SHARE_DIR" ] || [ -f "$BROGUE_WRAPPER_SCRIPT" ]; then
        echo "Cleaning up previous installation..."
        rm -rf "$INSTALL_SHARE_DIR" "$BROGUE_WRAPPER_SCRIPT"
        echo "Previous installation cleaned."
    fi
    # --- End Cleanup ---


    # Get the latest release download URL for the Linux tarball (x86_64)
    echo "Fetching latest release information from GitHub..."
    LATEST_URL=$(curl -s https://api.github.com/repos/tmewett/BrogueCE/releases/latest | jq -r ".assets[] | select(.name | test(\".*linux-x86_64.tar.gz$\")) | .browser_download_url")

    if [ -z "$LATEST_URL" ]; then
        echo "Error: Could not find the latest BrogueCE release URL for Linux (x86_64)."
        echo "Please check the releases page manually: https://github.com/tmewett/BrogueCE/releases"
        exit 1
    fi

    # Define download and extraction paths
    DOWNLOAD_TARBALL="$(mktemp -t broguece-tarball-XXXXXX).tar.gz" # Use a temporary file for download

    # Download the tarball using curl
    echo "Downloading BrogueCE from $LATEST_URL..."
    # Note: --progress-bar is good for interactive use, consider removing or making optional for scripting
    if curl -L --progress-bar "$LATEST_URL" -o "$DOWNLOAD_TARBALL"; then
        echo "Download complete."
    else
        echo "Error: Download failed."
        rm -f "$DOWNLOAD_TARBALL"
        exit 1
    fi


    # Create the installation directory for game files
    echo "Creating installation directory: $INSTALL_SHARE_DIR..."
    mkdir -p "$INSTALL_SHARE_DIR"

    # Extract the tarball into the installation directory
    echo "Extracting BrogueCE to $INSTALL_SHARE_DIR..."
    # Find the top-level directory inside the tarball to strip it
    TAR_TOP_DIR=$(tar -tf "$DOWNLOAD_TARBALL" | head -n 1 | sed -e 's/\/.*//')
    if [ -z "$TAR_TOP_DIR" ]; then
        echo "Error: Could not determine the top-level directory in the tarball."
        rm -f "$DOWNLOAD_TARBALL"
        rm -rf "$INSTALL_SHARE_DIR" # Clean up potentially created dir
        exit 1
    fi

    if tar -xzf "$DOWNLOAD_TARBALL" -C "$INSTALL_SHARE_DIR" --strip-components=1; then
         echo "Extraction complete."
    else
         echo "Error: Extraction failed."
         rm -f "$DOWNLOAD_TARBALL"
         rm -rf "$INSTALL_SHARE_DIR"
         exit 1
    fi

    # Check if the brogue executable exists after extraction
    if [ ! -f "$BROGUE_EXECUTABLE_IN_SHARE" ] || [ ! -x "$BROGUE_EXECUTABLE_IN_SHARE" ]; then
        echo "Error: Could not find or execute 'brogue' executable in the extracted files."
        echo "Expected path: $BROGUE_EXECUTABLE_IN_SHARE"
        echo "Listing contents of $INSTALL_SHARE_DIR:"
        ls -lR "$INSTALL_SHARE_DIR"
        rm -rf "$INSTALL_SHARE_DIR"
        rm -f "$DOWNLOAD_TARBALL"
        exit 1
    fi
    echo "BrogueCE executable found."

    # Check if the assets directory exists after extraction
     if [ ! -d "$BROGUE_ASSET_DIR_IN_SHARE" ] || [ ! -r "$BROGUE_ASSET_DIR_IN_SHARE" ]; then
        echo "Error: Could not find or read the 'assets' directory in the extracted files."
        echo "Expected path: $BROGUE_ASSET_DIR_IN_SHARE"
        echo "Listing contents of $INSTALL_SHARE_DIR:"
        ls -lR "$INSTALL_SHARE_DIR"
        rm -rf "$INSTALL_SHARE_DIR"
        rm -f "$DOWNLOAD_TARBALL"
        exit 1
     fi
     echo "BrogueCE assets directory found."


    # Create the bin directory if it doesn't exist
    mkdir -p "$INSTALL_BIN_DIR"

    # Create a wrapper script in ~/.local/bin that sets BROGUE_ASSET_DIR and runs the game
    echo "Creating wrapper script for 'brogue' in $INSTALL_BIN_DIR..."
    cat << EOF > "$BROGUE_WRAPPER_SCRIPT"
#!/bin/bash
# Wrapper script to run BrogueCE with correct asset path

# Define installation paths relative to HOME
BROGUE_SHARE_DIR="\$HOME/.local/share/brogue-ce"
BROGUE_BIN_PATH="\$BROGUE_SHARE_DIR/bin/brogue"
BROGUE_ASSET_PATH="\$BROGUE_SHARE_DIR/assets"

# Check if the actual binary exists
if [ ! -x "\$BROGUE_BIN_PATH" ]; then
    echo "Error: BrogueCE executable not found at \$BROGUE_BIN_PATH. Installation may be incomplete." >&2
    exit 1
fi

# Check if assets directory exists
if [ ! -d "\$BROGUE_ASSET_PATH" ]; then
     echo "Error: BrogueCE assets directory not found at \$BROGUE_ASSET_PATH. Installation may be incomplete." >&2
     echo "Please ensure the game was installed correctly to \$BROGUE_SHARE_DIR" >&2
     exit 1
fi

# Set the asset directory environment variable and execute the game
# 'exec' replaces the current shell process with the game, passing arguments (\$@)
BROGUE_ASSET_DIR="\$BROGUE_ASSET_PATH" exec "\$BROGUE_BIN_PATH" "\$@"
EOF

    # Make the wrapper script executable
    chmod +x "$BROGUE_WRAPPER_SCRIPT"
    echo "Wrapper script created and made executable."


    # Cleanup the downloaded tarball
    rm -f "$DOWNLOAD_TARBALL"
    echo "Downloaded tarball cleaned up."

    echo "BrogueCE installation completed successfully."
}

# --- Main Script Logic ---

echo "--- BrogueCE Installation Script ---"

# 1. Check and install dependencies (basic tools and SDL2_image)
check_and_install_dependencies

# 2. Setup BrogueCE installation (downloads, extracts, creates wrapper)
#    This function includes cleanup of previous installations.
setup_brogue_installation

# 3. Ensure the installation directory for executables is on the PATH
echo "" # Add a newline for cleaner output
echo "Checking/Updating PATH..."
if [[ ":$PATH:" != *":$INSTALL_BIN_DIR:"* ]]; then
    echo "$INSTALL_BIN_DIR is not in the current PATH."
    SHELL_RC="$HOME/.$(basename "$SHELL")rc"
    if [ -f "$SHELL_RC" ]; then
        # Add only if not already present to avoid duplicates on subsequent runs
        if ! grep -q "export PATH=.*$INSTALL_BIN_DIR" "$SHELL_RC"; then
            echo "" >> "$SHELL_RC" # Add a newline just in case
            echo "# Add BrogueCE local bin directory to PATH" >> "$SHELL_RC"
            echo "export PATH=\"$INSTALL_BIN_DIR:\$PATH\"" >> "$SHELL_RC"
            echo "Added '$INSTALL_BIN_DIR' to PATH in '$SHELL_RC'."
            # Note: 'source' might not work reliably in all contexts.
            # Inform the user they might need a new terminal.
        else
             echo "'$INSTALL_BIN_DIR' is already listed in '$SHELL_RC'."
        fi
    else
        echo "Warning: Could not find shell rc file ('$SHELL_RC') to automatically add '$INSTALL_BIN_DIR' to PATH."
        echo "Please manually add '$INSTALL_BIN_DIR' to your PATH environment variable."
    fi
else
    echo "'$INSTALL_BIN_DIR' is already in the current PATH."
fi

echo "" # Add a newline for cleaner output
echo "--- Installation Complete ---"
echo "You should now be able to run 'brogue' from any terminal session."
echo "If you ran this script and it updated your shell configuration:"
echo "  - You may need to close and reopen your terminal, OR"
echo "  - Run 'source $SHELL_RC' in your current terminal to update your PATH."
echo ""
echo "--- Basic BrogueCE Tips & Controls ---"
echo "Goal: Descend to dungeon depth 26, retrieve the Amulet of Yendor."
echo "Movement: Arrow keys, numpad, or vi keys (hjklyubn)."
echo "Basic Actions:"
echo "  , : Pick up item"
echo "  < : Go upstairs"
echo "  > : Go downstairs"
echo "  i : Inventory"
echo "  d : Drop item"
echo "  q : Quiver item (prepare to throw)"
echo "  t : Throw quivered item"
echo "  w : Wield weapon"
echo "  e : Eat food"
echo "  r : Read scroll"
echo "  p : Apply potion"
echo "  z : Zap staff"
echo "  c : Character info"
echo "  / : Look at/identify object/monster"
echo "  s : Search for secrets/traps (use near walls/doors)"
echo "  ? : View full help and keybindings"
echo "Tips:"
echo "  - Identify items carefully (especially scrolls and potions!)"
echo "  - Observe monster behavior before engaging."
echo "  - Retreat and use terrain to your advantage."
echo "  - Magic items improve over time ('enchantment')."
echo ""
echo "Good luck in the Dungeons of Doom!"
