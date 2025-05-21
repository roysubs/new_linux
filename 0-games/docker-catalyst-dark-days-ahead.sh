#!/bin/bash

# Script to check for catalauncher, guide setup, (optionally) download it, and provide info

echo "=== Catalauncher & CDDA Container Helper (v4 - Robust Release Fetching) ==="
echo

# --- Configuration ---
DEFAULT_WORLD_NAME="my-cdda-world"
CATALAUNCHER_REPO="houseabsolute/catalauncher"
CATALAUNCHER_GITHUB_URL="https://github.com/${CATALAUNCHER_REPO}"
CATALAUNCHER_RELEASES_URL="${CATALAUNCHER_GITHUB_URL}/releases"
CATALAUNCHER_API_RELEASES_ARRAY_URL="https://api.github.com/repos/${CATALAUNCHER_REPO}/releases" # Changed from /latest

CATALAUNCHER_CMD="catalauncher" # Default command if already in PATH
TEMP_CATALAUNCHER_DIR=""
DOWNLOADED_ASSET_IS_ARCHIVE=false

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
CATALAUNCHER_CONFIG_DIR_LINUX_MODERN="~/.config/catalauncher"
CATALAUNCHER_WORLDS_DIR_LINUX_MODERN="~/.local/share/catalauncher/worlds"
CATALAUNCHER_CONFIG_DIR_MACOS_MODERN="~/Library/Application Support/org.houseabsolute.catalauncher"
CATALAUNCHER_WORLDS_DIR_MACOS_MODERN="~/Library/Application Support/catalauncher/worlds"
# Legacy path for very old versions, if detected
CATALAUNCHER_CONFIG_LEGACY="~/.catalauncher/config.toml"


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

  for cmd in curl jq tar; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "[ERROR] '$cmd' is required to download and extract catalauncher automatically, but it's not installed."
      echo "         Please install '$cmd' or install 'catalauncher' manually from ${CATALAUNCHER_RELEASES_URL}"
      exit 1
    fi
  done

  OS_KERNEL=$(uname -s)
  OS_ARCH_ORIGINAL=$(uname -m)
  TARGET_OS=""
  TARGET_ARCH_MODERN=""
  TARGET_ARCH_LEGACY=""

  case "$OS_KERNEL" in
    Linux) TARGET_OS="linux" ;;
    Darwin) TARGET_OS="macos" ;;
    *) echo "[ERROR] Unsupported OS: $OS_KERNEL." && exit 1 ;;
  esac
  TARGET_OS_CAPITALIZED=$(echo "$TARGET_OS" | awk '{print toupper(substr($0,1,1))substr($0,2)}')

  case "$OS_ARCH_ORIGINAL" in
    x86_64) TARGET_ARCH_MODERN="amd64"; TARGET_ARCH_LEGACY="x86_64" ;;
    aarch64 | arm64) TARGET_ARCH_MODERN="arm64"; TARGET_ARCH_LEGACY="$OS_ARCH_ORIGINAL" ;;
    *) echo "[ERROR] Unsupported arch: $OS_ARCH_ORIGINAL." && exit 1 ;;
  esac

  echo "[INFO] Fetching release list from GitHub API..."
  ALL_RELEASES_JSON=$(curl -s -L "${CATALAUNCHER_API_RELEASES_ARRAY_URL}")

  if [[ -z "$ALL_RELEASES_JSON" ]]; then
      echo "[ERROR] Failed to fetch release list from GitHub API."
      exit 1
  fi

  # Select the latest, non-prerelease, non-draft release
  # Sort by published_at, then take the last one (most recent)
  LATEST_STABLE_RELEASE_JSON=$(echo "$ALL_RELEASES_JSON" | \
    jq '[.[] | select(.prerelease == false and .draft == false)] | sort_by(.published_at) | .[-1]')


  if [[ -z "$LATEST_STABLE_RELEASE_JSON" || "$LATEST_STABLE_RELEASE_JSON" == "null" ]]; then
    echo "[ERROR] Could not determine the latest stable release from GitHub API."
    echo "         No non-prerelease, non-draft releases found, or API error."
    echo "         Please download catalauncher manually from ${CATALAUNCHER_RELEASES_URL}"
    exit 1
  fi
  
  RELEASE_TAG_NAME=$(echo "$LATEST_STABLE_RELEASE_JSON" | jq -r .tag_name)
  RELEASE_VERSION_NUMBER=$(echo "$RELEASE_TAG_NAME" | sed 's/^v//')
  echo "[INFO] Identified latest stable release: ${RELEASE_TAG_NAME}"

  ASSET_NAME_MODERN="catalauncher-${TARGET_OS}-${TARGET_ARCH_MODERN}"
  echo "[INFO] Attempting to find modern asset: ${ASSET_NAME_MODERN} in release ${RELEASE_TAG_NAME}"
  DOWNLOAD_URL=$(echo "$LATEST_STABLE_RELEASE_JSON" | jq -r ".assets[] | select(.name == \"${ASSET_NAME_MODERN}\") | .browser_download_url")

  if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
    ASSET_NAME_LEGACY="catalauncher_${RELEASE_VERSION_NUMBER}_${TARGET_OS_CAPITALIZED}_${TARGET_ARCH_LEGACY}.tar.gz"
    echo "[INFO] Modern asset not found. Attempting to find legacy asset: ${ASSET_NAME_LEGACY} in release ${RELEASE_TAG_NAME}"
    DOWNLOAD_URL=$(echo "$LATEST_STABLE_RELEASE_JSON" | jq -r ".assets[] | select(.name == \"${ASSET_NAME_LEGACY}\") | .browser_download_url")
    if [[ -n "$DOWNLOAD_URL" && "$DOWNLOAD_URL" != "null" ]]; then
      DOWNLOADED_ASSET_IS_ARCHIVE=true
    fi
  fi

  if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
    echo "[ERROR] Could not find a suitable download URL for your system (OS: ${TARGET_OS}, Arch: ${OS_ARCH_ORIGINAL}) in release ${RELEASE_TAG_NAME}."
    echo "         Tried modern pattern: '${ASSET_NAME_MODERN}'"
    if [[ -n "$ASSET_NAME_LEGACY" ]]; then
        echo "         Tried legacy pattern: '${ASSET_NAME_LEGACY}'"
    fi
    echo "         Available assets in release '${RELEASE_TAG_NAME}':"
    echo "$LATEST_STABLE_RELEASE_JSON" | jq -r '.assets[].name'
    echo "         Please download catalauncher manually from ${CATALAUNCHER_RELEASES_URL}"
    exit 1
  fi

  echo "[INFO] Found download URL: $DOWNLOAD_URL"
  ASSET_FILENAME=$(basename "$DOWNLOAD_URL")

  TEMP_CATALAUNCHER_DIR=$(mktemp -d -p "/tmp" catalauncher_XXXXXX)
  CATALAUNCHER_DOWNLOAD_PATH="${TEMP_CATALAUNCHER_DIR}/${ASSET_FILENAME}"
  echo "[INFO] Downloading to ${CATALAUNCHER_DOWNLOAD_PATH}..."
  if curl -L --progress-bar "$DOWNLOAD_URL" -o "$CATALAUNCHER_DOWNLOAD_PATH"; then
    echo "[INFO] Download successful."
    
    if [ "$DOWNLOADED_ASSET_IS_ARCHIVE" = true ]; then
      echo "[INFO] Asset is an archive, attempting to extract..."
      EXTRACT_SUBDIR="${TEMP_CATALAUNCHER_DIR}/extracted"
      mkdir -p "$EXTRACT_SUBDIR"
      if tar -xzf "$CATALAUNCHER_DOWNLOAD_PATH" -C "$EXTRACT_SUBDIR"; then
        echo "[INFO] Extraction successful."
        POTENTIAL_BINARY_PATH=""
        if [[ -f "${EXTRACT_SUBDIR}/catalauncher" && -x "${EXTRACT_SUBDIR}/catalauncher" ]]; then
            POTENTIAL_BINARY_PATH="${EXTRACT_SUBDIR}/catalauncher"
        else
            FOUND_BINARY=$(find "$EXTRACT_SUBDIR" -name "catalauncher" -type f -executable 2>/dev/null | head -n 1)
            if [[ -n "$FOUND_BINARY" && -x "$FOUND_BINARY" ]]; then POTENTIAL_BINARY_PATH="$FOUND_BINARY"; fi
        fi

        if [[ -n "$POTENTIAL_BINARY_PATH" ]]; then
          chmod +x "$POTENTIAL_BINARY_PATH"
          CATALAUNCHER_CMD="$POTENTIAL_BINARY_PATH"
          echo "[INFO] Catalauncher binary found at ${CATALAUNCHER_CMD}"
        else
          echo "[ERROR] Could not find 'catalauncher' executable in the extracted archive." && exit 1
        fi
      else
        echo "[ERROR] Failed to extract archive ${CATALAUNCHER_DOWNLOAD_PATH}." && exit 1
      fi
    else
      chmod +x "$CATALAUNCHER_DOWNLOAD_PATH"
      if [[ -x "$CATALAUNCHER_DOWNLOAD_PATH" ]]; then
          echo "[INFO] Catalauncher is now executable at ${CATALAUNCHER_DOWNLOAD_PATH}"
          CATALAUNCHER_CMD="$CATALAUNCHER_DOWNLOAD_PATH"
      else
          echo "[ERROR] Failed to make downloaded file executable: ${CATALAUNCHER_DOWNLOAD_PATH}" && exit 1
      fi
    fi
  else
    echo "[ERROR] Download failed." && exit 1
  fi
fi
print_separator

# --- Operate with Catalauncher ---
IS_OLD_CATALAUNCHER=false
CATALAUNCHER_VERSION_OUTPUT=$(${CATALAUNCHER_CMD} --version 2>&1)
if [[ $? -ne 0 ]]; then
    # --version failed, try to get help output to see if it's the old version
    CATALAUNCHER_HELP_OUTPUT=$(${CATALAUNCHER_CMD} --help 2>&1) # Old version typically errors on --help too, use just help
    if [[ "$CATALAUNCHER_HELP_OUTPUT" == *"unknown flag: --version"* ]] || \
       [[ "$CATALAUNCHER_HELP_OUTPUT" == *"Error: unknown command \"--help\""* ]] || \
       [[ "$(${CATALAUNCHER_CMD} help 2>&1)" == *"Usage:"* && "$(${CATALAUNCHER_CMD} help 2>&1)" == *"Available Commands:"* && "$(${CATALAUNCHER_CMD} help 2>&1)" != *"list"* ]]; then
        IS_OLD_CATALAUNCHER=true
        echo "[WARNING] Downloaded catalauncher appears to be an OLD version (e.g., v0.0.6)."
        echo "           It does not support '--version' or modern commands like 'list'."
        echo "           Output from '${CATALAUNCHER_CMD}':"
        ${CATALAUNCHER_CMD} # just run it to show basic help
    else
        echo "[WARNING] Could not determine catalauncher version using '${CATALAUNCHER_CMD} --version'."
        echo "           Output: $CATALAUNCHER_VERSION_OUTPUT"
    fi
    echo "[INFO] Using catalauncher from: ${CATALAUNCHER_CMD}"
else
    echo "[INFO] Using catalauncher: ${CATALAUNCHER_VERSION_OUTPUT} (from ${CATALAUNCHER_CMD})"
fi
print_separator

if [ "$IS_OLD_CATALAUNCHER" = true ]; then
    echo "[INFO] Since an OLD version of catalauncher was downloaded, some features described below may not work as expected."
    echo "       Available commands for this old version are likely 'setup', 'launch', 'clean'."
    echo "       Consider manually installing a newer version from ${CATALAUNCHER_RELEASES_URL} for full functionality."
    print_separator
    echo "[INFO] Data storage for this OLD version might be: ${CATALAUNCHER_CONFIG_LEGACY}"
    print_separator
else
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

    echo "[INFO] Catalauncher Command Summary (Key Operations - for MODERN versions):"
    echo
    printf "%-30s %s\n" "COMMAND" "DESCRIPTION"
    # ... (rest of command summary as before)
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

    echo "[INFO] Catalauncher Data Storage Locations (on your computer, outside the container - for MODERN versions):"
    echo
    echo "Catalauncher's own configuration file:"
    if [[ "$OS_TYPE" == "Linux" ]]; then
      echo "  - Linux:   ${CATALAUNCHER_CONFIG_DIR_LINUX_MODERN}/catalauncher.toml"
      echo "             (May also use \$XDG_CONFIG_HOME/catalauncher/catalauncher.toml)"
    elif [[ "$OS_TYPE" == "Darwin" ]]; then
      echo "  - macOS:   ${CATALAUNCHER_CONFIG_DIR_MACOS_MODERN}/catalauncher.toml"
    else
      echo "  - Typically in a standard config directory for your OS."
    fi
    echo

    echo "CDDA Game Data (saves, config, mods, etc. for each world):"
    if [[ "$OS_TYPE" == "Linux" ]]; then
      echo "  - Linux:   ${CATALAUNCHER_WORLDS_DIR_LINUX_MODERN}/<world_name>/"
      echo "             (May also use \$XDG_DATA_HOME/catalauncher/worlds/<world_name>/)"
    elif [[ "$OS_TYPE" == "Darwin" ]]; then
      echo "  - macOS:   ${CATALAUNCHER_WORLDS_DIR_MACOS_MODERN}/<world_name>/"
    else
      echo "  - Typically in a standard data directory for your OS."
    fi
    echo "  Replace '<world_name>' with the actual name of your game instance (e.g., '${DEFAULT_WORLD_NAME}')."
fi
echo
echo "[INFO] All your game progress and settings are persistently stored on your host machine,"
echo "       ensuring they survive container recreation or updates."
print_separator
echo "Script finished. If catalauncher was downloaded, its temporary files will be removed shortly."

# Trap will call cleanup_temp_dir on EXIT
