#!/bin/bash

# --- Configuration ---
REPO_URL="https://github.com/andrewtweber/umoria-color.git"
TEMP_BUILD_DIR="/tmp/umoria-color_build_temp"
TARGET_INSTALL_DIR="$HOME/.local/games/umoria-color"
TARGET_BIN_DIR="$TARGET_INSTALL_DIR/bin"
TARGET_SHARE_DIR="$TARGET_INSTALL_DIR/share/umoria-color"
GAME_EXEC_NAME="umoria"
LINK_NAME="umoria-color"
LINK_PATH="$HOME/.local/bin/$LINK_NAME"
REQUIRED_PACKAGES="build-essential git cmake libncurses-dev"

# --- Function to display commands ---
display_commands_summary() {
    echo "--- Common Umoria Commands ---"
    column -t << EOF
Movement:            h/j/k/l (left/down/up/right)    y/u/n/b (diagonals)    ./run (run in direction)
Actions:             o (open door/chest)             c (close door)         s (search for traps/doors)
                     t (tunnel)                      m (cast spell)         p (pray)
Inventory/Items:     i (inventory)                   e (equipment)          w (wear/wield)
                     t (take off)                    d (drop)               q (quaff potion)
                     r (read scroll/book)            a (aim wand)           f (fire/throw item)
                     { (inscribe item)               x (exchange weapons)   = (set options)
Game State:          > (down stairs)                 < (up stairs)          V (view scoreboard)
                     S (search mode toggle)          R (rest)               ? (command help)
                     CTRL-X (save and quit)          CTRL-K (quit game)
EOF
    echo "-----------------------------"
}

# --- Main Script ---

echo "Umoria COLOR Installation and Launcher Script"
echo "-----------------------------------------"

# Check if the game is already linked
if [ -L "$LINK_PATH" ]; then
    echo "Umoria COLOR appears to be already installed (link found at $LINK_PATH)."
    SKIP_INSTALL=true
else
    echo "Umoria COLOR not found at $LINK_PATH. Proceeding with installation."
    SKIP_INSTALL=false
fi

# --- Installation Section ---
if [ "$SKIP_INSTALL" = false ]; then

    echo "Installing required packages: $REQUIRED_PACKAGES"
    if ! sudo apt update && sudo apt install -y $REQUIRED_PACKAGES; then
        echo "Error: Failed to install required packages."
        echo "Please ensure you have internet access and can run 'sudo'."
        exit 1
    fi
    echo "Required packages installed."

    echo "Cloning Umoria COLOR repository..."
    # Clean up previous temporary directory if it exists
    if [ -d "$TEMP_BUILD_DIR" ]; then
        echo "Cleaning up previous temporary build directory: $TEMP_BUILD_DIR"
        rm -rf "$TEMP_BUILD_DIR"
    fi

    if ! git clone "$REPO_URL" "$TEMP_BUILD_DIR"; then
        echo "Error: Failed to clone the repository."
        exit 1
    fi
    echo "Repository cloned to $TEMP_BUILD_DIR."

    echo "Compiling the game..."
    cd "$TEMP_BUILD_DIR" || exit 1 # Exit if cd fails
    mkdir build
    cd build || exit 1 # Exit if cd fails

    if ! cmake ..; then
        echo "Error: CMake configuration failed."
        exit 1
    fi

    if ! make -j "$(nproc)"; then
        echo "Error: Compilation failed."
        exit 1
    fi
    echo "Compilation complete."

    echo "Installing game files to $TARGET_INSTALL_DIR..."
    # Clean up previous installation directory if it exists
    if [ -d "$TARGET_INSTALL_DIR" ]; then
        echo "Cleaning up previous installation directory: $TARGET_INSTALL_DIR"
        rm -rf "$TARGET_INSTALL_DIR"
    fi

    mkdir -p "$TARGET_BIN_DIR" || exit 1 # Exit if mkdir fails
    mkdir -p "$TARGET_SHARE_DIR" || exit 1 # Exit if mkdir fails

    # Copy the compiled executable
    if [ -f "./$GAME_EXEC_NAME" ]; then
        cp "./$GAME_EXEC_NAME" "$TARGET_BIN_DIR/" || exit 1 # Exit if cp fails
    else
        echo "Error: Compiled executable '$GAME_EXEC_NAME' not found in build directory."
        exit 1
    fi

    # Copy necessary data files (adjust this copy pattern based on exact needs if necessary)
    # This copies common data file types from the original source directory
    find "$TEMP_BUILD_DIR" -maxdepth 1 -type f \( -name "*.txt" -o -name "*.orig" -o -name "*.color" \) -exec cp {} "$TARGET_SHARE_DIR/" \;
    # Ensure colors.txt is copied as it's specifically for the color variant
     if [ -f "$TEMP_BUILD_DIR/colors.txt" ]; then
         cp "$TEMP_BUILD_DIR/colors.txt" "$TARGET_SHARE_DIR/" || exit 1
     fi


    echo "Creating symbolic link $LINK_PATH -> $TARGET_BIN_DIR/$GAME_EXEC_NAME"
    # Ensure ~/.local/bin exists and is in PATH
    mkdir -p "$HOME/.local/bin"
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "Warning: $HOME/.local/bin is not in your PATH."
        echo "You may need to add it to your shell configuration (~/.bashrc, ~/.profile, etc.)"
        echo "After adding, you might need to log out and back in or run 'source ~/.bashrc'."
    fi

    if ! ln -sf "$TARGET_BIN_DIR/$GAME_EXEC_NAME" "$LINK_PATH"; then
        echo "Error: Failed to create symbolic link."
        exit 1
    fi
    echo "Installation complete. You can now run the game using the command '$LINK_NAME'."

    # Clean up the temporary build directory
    echo "Cleaning up temporary build directory: $TEMP_BUILD_DIR"
    rm -rf "$TEMP_BUILD_DIR"

else
    echo "Skipping installation as the game is already linked."
fi

# --- Game Launch Section ---
echo ""
display_commands_summary

echo ""
read -n 1 -r -p "Press any key to start Umoria COLOR..."
echo "" # Add a newline after the prompt

# Launch the game, replacing the current script process
if [ -x "$LINK_PATH" ]; then
    echo "Starting game..."
    exec "$LINK_PATH"
else
    echo "Error: Game executable not found or is not executable at $LINK_PATH."
    exit 1
fi

exit 0 # Should not be reached if exec is successful
