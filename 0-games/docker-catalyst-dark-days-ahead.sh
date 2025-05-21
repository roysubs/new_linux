#!/bin/bash

# Script to check for catalauncher, guide setup, (optionally) download it, and provide info

echo "=== Catalauncher & CDDA Container Helper (v2 - Automated Download Attempt) ==="
echo

# --- Configuration ---
DEFAULT_WORLD_NAME="my-cdda-world"
CATALAUNCHER_REPO="houseabsolute/catalauncher"
CATALAUNCHER_GITHUB_URL="https://github.com/${CATALAUNCHER_REPO}"
CATALAUNCHER_RELEASES_URL="${CATALAUNCHER_GITHUB_URL}/releases"
CATALAUNCHER_API_LATEST_RELEASE_URL="https://api.github.com/repos/${CATALAUNCHER_REPO}/releases/latest"

CATALAUNCHER_CMD="catalauncher" # Default command if already in PATH
TEMP_CATALAUNCHER_DIR=""

# --- Helper Functions ---
print_separator() {
  echo "--------------------------------------------------"
}

cleanup_temp_dir() {
  if [[ -n "$TEMP_CATALAUNCHER_DIR" && -d "$TEMP_CATALAUNCHER_DIR" ]]; then
    echo "[INFO] Cleaning up temporary directory: $TEMP_CATALAUNCHER_DIR"
    rm -rf "$TEMP_CATALAUNCHER_DIR"
  fi
}
# Setup trap to clean up on exit
trap cleanup_temp_dir EXIT

# Determine OS for path examples
OS_TYPE=$(uname -s)
CATALAUNCHER_CONFIG_DIR_LINUX="~/.config/catalauncher"
CATALAUNCHER_WORLDS_DIR_LINUX="~/.local/share/catalauncher/worlds"
CATALAUNCHER_CONFIG_DIR_MACOS="~/Library/Application Support/org.houseabsolute.catalauncher"
CATALAUNCHER_WORLDS_DIR_MACOS="~/Library/Application Support/catalauncher/worlds"

# --- Prerequisite Checks ---
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

# --- Catalauncher Setup ---
if command -v catalauncher &> /dev/null; then
  echo "[INFO] 'catalauncher' is already installed and found in your PATH."
  CATALAUNCHER_CMD="catalauncher"
else
  echo "[INFO] 'catalauncher' command not found in your PATH."
  echo "[INFO] Attempting to download it for this session..."

  # Check for curl and jq
  if ! command -v curl &> /dev/null; then
    echo "[ERROR] 'curl' is required to download catalauncher automatically, but it's not installed."
    echo "         Please install 'curl' or install 'catalauncher' manually from ${CATALAUNCHER_RELEASES_URL}"
    exit 1
  fi
  if ! command -v jq &> /dev/null; then
    echo "[ERROR] 'jq' is required to download catalauncher automatically, but it's not installed."
    echo "         Please install 'jq' (e.g., 'sudo apt install jq' or 'brew install jq') or install 'catalauncher' manually from ${CATALAUNCHER_RELEASES_URL}"
    exit 1
  fi

  # Determine OS and Architecture
  OS_KERNEL=$(uname -s)
  OS_ARCH=$(uname -m)
  TARGET_OS=""
  TARGET_ARCH=""

  case "$OS_KERNEL" in
    Linux) TARGET_OS="linux" ;;
    Darwin) TARGET_OS="macos" ;;
    *)
      echo "[ERROR] Unsupported operating system: $OS_KERNEL for automatic download."
      echo "         Please download catalauncher manually from ${CATALAUNCHER_RELEASES_URL}"
      exit 1
      ;;
  esac

  case "$OS_ARCH" in
    x86_64) TARGET_ARCH="amd64" ;;
    aarch64 | arm64) TARGET_ARCH="arm64" ;;
    *)
      echo "[ERROR] Unsupported architecture: $OS_ARCH for automatic download."
      echo "         Please download catalauncher manually from ${CATALAUNCHER_RELEASES_URL}"
      exit 1
      ;;
  esac

  ASSET_NAME_PATTERN="catalauncher-${TARGET_OS}-${TARGET_ARCH}"
  echo "[INFO] Detected System: OS=${TARGET_OS}, Arch=${TARGET_ARCH}. Looking for asset: ${ASSET_NAME_PATTERN}"

  # Fetch release info and download URL
  echo "[INFO] Fetching latest release information from GitHub..."
  # shellcheck disable=SC2086 # We want word splitting for curl opts if any
  RELEASE_INFO_JSON=$(curl -s -L ${CATALAUNCHER_API_LATEST_RELEASE_URL})

  if [[ -z "$RELEASE_INFO_JSON" ]]; then
      echo "[ERROR] Failed to fetch release information from GitHub."
      echo "         Please check your internet connection or try downloading manually from ${CATALAUNCHER_RELEASES_URL}"
      exit 1
  fi
  
  DOWNLOAD_URL=$(echo "$RELEASE_INFO_JSON" | jq -r ".assets[] | select(.name == \"${ASSET_NAME_PATTERN}\") | .browser_download_url")

  if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
    echo "[ERROR] Could not find a download URL for asset '${ASSET_NAME_PATTERN}'."
    echo "         Available assets:"
    echo "$RELEASE_INFO_JSON" | jq -r '.assets[].name'
    echo "         Please download catalauncher manually from ${CATALAUNCHER_RELEASES_URL}"
    exit 1
  fi

  echo "[INFO] Found download URL: $DOWNLOAD_URL"

  # Download to /tmp
  TEMP_CATALAUNCHER_DIR=$(mktemp -d -p "/tmp" catalauncher_XXXXXX)
  if [[ -z "$TEMP_CATALAUNCHER_DIR" ]]; then
    echo "[ERROR] Could not create temporary directory in /tmp."
    exit 1
  fi
  
  CATALAUNCHER_DOWNLOAD_PATH="${TEMP_CATALAUNCHER_DIR}/catalauncher"
  echo "[INFO] Downloading to ${CATALAUNCHER_DOWNLOAD_PATH}..."
  # shellcheck disable=SC2086 # We want word splitting for curl opts if any
  if curl -L --progress-bar "$DOWNLOAD_URL" -o "$CATALAUNCHER_DOWNLOAD_PATH"; then
    echo "[INFO] Download successful."
    chmod +x "$CATALAUNCHER_DOWNLOAD_PATH"
    if [[ -x "$CATALAUNCHER_DOWNLOAD_PATH" ]]; then
        echo "[INFO] Catalauncher is now executable at ${CATALAUNCHER_DOWNLOAD_PATH}"
        CATALAUNCHER_CMD="$CATALAUNCHER_DOWNLOAD_PATH"
    else
        echo "[ERROR] Failed to make the downloaded file executable."
        echo "         Please check permissions or download manually from ${CATALAUNCHER_RELEASES_URL}"
        exit 1
    fi
  else
    echo "[ERROR] Download failed."
    echo "         Please check your internet connection or download manually from ${CATALAUNCHER_RELEASES_URL}"
    exit 1
  fi
fi
print_separator

# --- Operate with Catalauncher ---
echo "[INFO] Using catalauncher from: $(${CATALAUNCHER_CMD} --version || echo "$CATALAUNCHER_CMD (version check failed)")" # Attempts to get version
print_separator

echo "[INFO] Checking for existing CDDA worlds managed by catalauncher..."
echo "        Running '${CATALAUNCHER_CMD} list':"
${CATALAUNCHER_CMD} list
echo
echo "        If the list is empty or you want a new world, you can create one."
echo "        For example, to create and then launch a world named '${DEFAULT_WORLD_NAME}':"
echo "          ${CATALAUNCHER_CMD} create ${DEFAULT_WORLD_NAME}"
echo "          ${CATALAUNCHER_CMD} launch ${DEFAULT_WORLD_NAME}"
echo "        The 'launch' command will automatically pull the latest stable CDDA Docker image if it's not already present."
echo "        To update the game for a specific world:"
echo "          ${CATALAUNCHER_CMD} update ${DEFAULT_WORLD_NAME}"
print_separator

# Display catalauncher commands
echo "[INFO] Catalauncher Command Summary (Key Operations):"
echo
printf "%-30s %s\n" "COMMAND" "DESCRIPTION"
printf "%-30s %s\n" "-----------------------------" "------------------------------------------------------------"
printf "%-30s %s\n" "${CATALAUNCHER_CMD} create NAME" "Creates a new CDDA world with the given NAME."
printf "%-30s %s\n" "${CATALAUNCHER_CMD} launch NAME" "Launches the CDDA game for the specified world."
printf "%-30s %s\n" " " "  (Downloads CDDA image if needed)."
printf "%-30s %s\n" "${CATALAUNCHER_CMD} update NAME" "Updates the CDDA version for the specified world."
printf "%-30s %s\n" "${CATALAUNCHER_CMD} list" "Lists all CDDA worlds managed by catalauncher."
printf "%-30s %s\n" "${CATALAUNCHER_CMD} remove NAME" "Removes a CDDA world (game files and saves)."
printf "%-30s %s\n" "${CATALAUNCHER_CMD} shell NAME" "Opens a shell inside the game container for the world."
printf "%-30s %s\n" "${CATALAUNCHER_CMD} prune-images" "Removes old, unused CDDA Docker images."
printf "%-30s %s\n" "${CATALAUNCHER_CMD} --help" "Shows all available commands and options."
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
echo "Script finished. If catalauncher was downloaded, it will be removed from /tmp shortly."

# Trap will call cleanup_temp_dir on EXIT
