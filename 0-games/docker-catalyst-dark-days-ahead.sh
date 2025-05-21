#!/bin/bash

# Script to check for catalauncher, guide setup, and provide info

echo "=== Catalauncher & CDDA Container Helper ==="
echo

# --- Configuration ---
# Default world name to suggest if none exist
DEFAULT_WORLD_NAME="my-cdda-world"
CATALAUNCHER_GITHUB_URL="https://github.com/houseabsolute/catalauncher"
CATALAUNCHER_RELEASES_URL="${CATALAUNCHER_GITHUB_URL}/releases"

# --- Helper Functions ---
print_separator() {
  echo "--------------------------------------------------"
}

# Determine OS for path examples
OS_TYPE=$(uname -s)
CATALAUNCHER_CONFIG_DIR_LINUX="~/.config/catalauncher"
CATALAUNCHER_WORLDS_DIR_LINUX="~/.local/share/catalauncher/worlds"
CATALAUNCHER_CONFIG_DIR_MACOS="~/Library/Application Support/org.houseabsolute.catalauncher" # As per recent catalauncher updates for macOS
CATALAUNCHER_WORLDS_DIR_MACOS="~/Library/Application Support/catalauncher/worlds" # Older path, or general user data path for macOS

# Check for Docker
if ! command -v docker &> /dev/null; then
  echo "[ERROR] Docker command not found."
  echo "        Catalauncher requires Docker to function."
  echo "        Please install Docker first. Visit https://www.docker.com/get-started"
  exit 1
fi

if ! docker info &> /dev/null; then
  echo "[ERROR] Docker daemon does not seem to be running."
  echo "        Please start your Docker daemon and try again."
  exit 1
fi
echo "[INFO] Docker is installed and appears to be running."
print_separator

# Check for catalauncher
if ! command -v catalauncher &> /dev/null; then
  echo "[INFO] 'catalauncher' command not found in your PATH."
  echo "        Catalauncher is a tool to download and run Cataclysm:DDA in Docker."
  print_separator
  echo "To install catalauncher:"
  echo "  1. Go to the releases page: ${CATALAUNCHER_RELEASES_URL}"
  echo "  2. Download the latest binary for your system (e.g., Linux x86_64, macOS amd64/arm64)."
  echo "  3. Make it executable: chmod +x ./catalauncher-..."
  echo "  4. Move it to a directory in your PATH (e.g., /usr/local/bin or ~/bin):"
  echo "     sudo mv ./catalauncher-... /usr/local/bin/catalauncher"
  echo "     (Ensure /usr/local/bin or your chosen directory is in your PATH environment variable)"
  print_separator
  echo "After installation, re-run this script."
  exit 1
else
  echo "[INFO] 'catalauncher' is installed!"
  CATALAUNCHER_VERSION=$(catalauncher --version)
  echo "        Version: ${CATALAUNCHER_VERSION}"
  print_separator

  echo "[INFO] Checking for existing CDDA worlds managed by catalauncher..."
  echo "        Running 'catalauncher list':"
  catalauncher list
  echo
  echo "        If the list is empty or you want a new world, you can create one."
  echo "        For example, to create and then launch a world named '${DEFAULT_WORLD_NAME}':"
  echo "          catalauncher create ${DEFAULT_WORLD_NAME}"
  echo "          catalauncher launch ${DEFAULT_WORLD_NAME}"
  echo "        The 'launch' command will automatically pull the latest stable CDDA Docker image if it's not already present."
  echo "        To update the game for a specific world:"
  echo "          catalauncher update ${DEFAULT_WORLD_NAME}"
  print_separator
fi

# Display catalauncher commands
echo "[INFO] Catalauncher Command Summary (Key Operations):"
echo
printf "%-25s %s\n" "COMMAND" "DESCRIPTION"
printf "%-25s %s\n" "-------------------------" "------------------------------------------------------------"
printf "%-25s %s\n" "catalauncher create NAME" "Creates a new CDDA world with the given NAME."
printf "%-25s %s\n" "catalauncher launch NAME" "Launches the CDDA game for the specified world."
printf "%-25s %s\n" " " "  (Downloads CDDA image if needed)."
printf "%-25s %s\n" "catalauncher update NAME" "Updates the CDDA version for the specified world."
printf "%-25s %s\n" "catalauncher list" "Lists all CDDA worlds managed by catalauncher."
printf "%-25s %s\n" "catalauncher remove NAME" "Removes a CDDA world (game files and saves)."
printf "%-25s %s\n" "catalauncher shell NAME" "Opens a shell inside the game container for the world."
printf "%-25s %s\n" "catalauncher prune-images" "Removes old, unused CDDA Docker images."
printf "%-25s %s\n" "catalauncher --help" "Shows all available commands and options."
print_separator

# Display configuration and save game locations
echo "[INFO] Catalauncher Data Storage Locations (on your computer, outside the container):"
echo
echo "Catalauncher's own configuration file:"
if [[ "$OS_TYPE" == "Linux" ]]; then
  echo "  - Linux:   ${CATALAUNCHER_CONFIG_DIR_LINUX}/catalauncher.toml"
  echo "             (May also use \$XDG_CONFIG_HOME/catalauncher/catalauncher.toml)"
elif [[ "$OS_TYPE" == "Darwin" ]]; then # Darwin is macOS
  echo "  - macOS:   ${CATALAUNCHER_CONFIG_DIR_MACOS}/catalauncher.toml"
else
  echo "  - Typically in a standard config directory for your OS (e.g., under ~/.config or ~/Library/Application Support)."
fi
echo

echo "CDDA Game Data (saves, config, mods, tilesets, soundpacks for each world):"
if [[ "$OS_TYPE" == "Linux" ]]; then
  echo "  - Linux:   ${CATALAUNCHER_WORLDS_DIR_LINUX}/<world_name>/"
  echo "             (May also use \$XDG_DATA_HOME/catalauncher/worlds/<world_name>/)"
elif [[ "$OS_TYPE" == "Darwin" ]]; then
  echo "  - macOS:   ${CATALAUNCHER_WORLDS_DIR_MACOS}/<world_name>/"
else
  echo "  - Typically in a standard data directory for your OS (e.g., under ~/.local/share or ~/Library/Application Support)."
fi
echo "  Replace '<world_name>' with the actual name of your game instance (e.g., '${DEFAULT_WORLD_NAME}')."
echo
echo "[INFO] All your game progress and settings are persistently stored on your host machine,"
echo "       ensuring they survive container recreation or updates."
print_separator
echo "Script finished."
