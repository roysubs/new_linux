#!/usr/bin/env bash

# Relevant $1 (GitHub repo path) for each project:
# neofetch: dylanaraps/neofetch
# 
# btop: aristocratos/btop
# 
# htop: htop-dev/htop
# 
# bottom: ClementTsang/bottom
# 
# dust: bootandy/dust
# 
# gdu: dundee/gdu
# 
# lsd: Peltoche/lsd
# 
# exa: sergiusens/exa
# 
# bat: sharkdp/bat
# 
# fd: sharkdp/fd
# 
# ripgrep: BurntSushi/ripgrep
# 
# procs: dalance/procs
# 
# delta: dandavison/delta
# 
# tokei: XAMPPRocky/tokei
# 
# gitui: extrawurst/gitui
# 
# gh-dash: simondeziel/gh-dash
# 
# gh: cli/cli
# 
# just: casey/just
# 
# watchexec: watchexec/watchexec
# 
# refactor: go-refactor/refactor
# 
# up: upstox/up
# 
# mdcat: denoland/mdcat
# 
# glow: charmbracelet/glow
# 
# qr: claudiodangelis/qrcp
# 
# fx: antonmedv/fx
# 
# jless: paulz/jless
# 
# yq: mikefarah/yq
# 
# dasel: tasdomas/dasel
# 
# xsv: xsv/xsv
# 
# httpie: httpie/httpie
# 
# xh: ducaale/xh
# 
# curlie: curlie/curlie
# 
# dog: ogozu/dog
# 
# bandwhich: maintainerofbandwhich/bandwhich
# 
# speedtest-cli: speedtest-cli/speedtest-cli
# 
# atuin: Atuinorg/atuin
# 
# age: FiloSottile/age
# 
# gping: Avaralth/gping
# 
# pass: zx2c4/pass
# 
# rclone: rclone/rclone
# 
# vault: hashicorp/vault
# 
# lolcat: caius/lolcat
# 
# figlet: toy/figlet
# 
# cowsay: ttinc/cowsay
# 
# pipes.sh: gobolinux/pipes.sh
# 
# cava: karlstav/cava
# 
# navi: denisidoro/navi

# Generic GitHub Release Installer
# Installs a binary from a GitHub release asset (.tar.gz or .zip)

# Strict mode
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # Fail a pipeline if any command fails, not just the last one.

# --- Configuration ---
# These can be overridden by command-line arguments

# Default installation directory
DEFAULT_INSTALL_DIR="/usr/local/bin"

# --- Helper Functions ---

# Print usage information
usage() {
  echo "Usage: $0 <repo> <asset_pattern> <binary_name> [install_dir]"
  echo ""
  echo "Arguments:"
  echo "  repo           GitHub repository in 'owner/repo' format (e.g., 'o2sh/onefetch')."
  echo "  asset_pattern  Regex pattern or exact filename to match the desired release asset."
  echo "                 (e.g., 'linux.*amd64.tar.gz', 'onefetch-.*-x86_64-linux.tar.gz', 'mytool.zip')"
  echo "  binary_name    Name of the executable file inside the archive (e.g., 'onefetch', 'gh', 'mycli')."
  echo "  install_dir    (Optional) Directory to install the binary to. Defaults to $DEFAULT_INSTALL_DIR."
  echo ""
  echo "Examples:"
  echo "  # Install latest onefetch"
  echo "  $0 o2sh/onefetch 'onefetch-.*-x86_64-linux.tar.gz' onefetch"
  echo ""
  echo "  # Install latest GitHub CLI (assuming Linux AMD64)"
  echo "  $0 cli/cli 'gh_.*_linux_amd64.tar.gz' gh /usr/local/bin" # Note: gh binary is in a subdirectory
  echo ""
  echo "  # Install a tool from a zip file"
  echo "  $0 jesseduffield/lazygit 'lazygit_.*_Linux_x86_64.tar.gz' lazygit"
}

# Check for required tools
check_deps() {
  local missing=0
  for tool in curl jq tar unzip find mktemp basename sudo; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "Error: Required command '$tool' not found." >&2
      missing=1
    fi
  done
  if [[ $missing -eq 1 ]]; then
    exit 1
  fi
}

# --- Main Script ---

# Check arguments
if [[ $# -lt 3 ]] || [[ $# -gt 4 ]]; then
  usage
  exit 1
fi

REPO="$1"
ASSET_PATTERN="$2"
TARGET_BINARY="$3"
INSTALL_DIR="${4:-$DEFAULT_INSTALL_DIR}"

# Validate repo format
if ! [[ "$REPO" =~ ^[^/]+/[^/]+$ ]]; then
    echo "Error: Invalid repository format '$REPO'. Use 'owner/repo'." >&2
    usage
    exit 1
fi

echo "--- Configuration ---"
echo "Repository:       $REPO"
echo "Asset Pattern:    $ASSET_PATTERN"
echo "Binary Name:      $TARGET_BINARY"
echo "Installation Dir: $INSTALL_DIR"
echo "---------------------"

check_deps

# Create a temporary directory for downloads and extraction
TMPDIR=$(mktemp -d)
# Ensure cleanup happens on script exit or interruption
trap 'echo "Cleaning up temporary directory..."; rm -rf "$TMPDIR"' EXIT

# Get latest release data from GitHub API
API_URL="https://api.github.com/repos/$REPO/releases/latest"
echo "Fetching latest release info from $API_URL..."
RELEASE_JSON=$(curl -sL --fail "$API_URL") || {
    echo "Error: Failed to fetch release info for '$REPO'. Check repository name and network." >&2
    exit 1
}

# Find the download URL for the asset matching the pattern using jq
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r --arg pattern "$ASSET_PATTERN" '.assets[] | select(.name | test($pattern; "i")) | .browser_download_url' | head -n 1)

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Error: Could not find a release asset matching pattern '$ASSET_PATTERN' for repository '$REPO'." >&2
  echo "Available assets in the latest release:" >&2
  echo "$RELEASE_JSON" | jq -r '.assets[].name' >&2
  exit 1
fi

FILENAME=$(basename "$DOWNLOAD_URL")
echo "Found matching asset: $FILENAME"

# Download the asset
echo "Downloading $FILENAME..."
curl -L --fail -o "$TMPDIR/$FILENAME" "$DOWNLOAD_URL" || {
    echo "Error: Failed to download '$FILENAME'." >&2
    exit 1
}
echo "Download complete."

# Extract the archive
echo "Extracting $FILENAME..."
pushd "$TMPDIR" > /dev/null # Change into temp dir for extraction, suppress output

if [[ "$FILENAME" == *.tar.gz ]] || [[ "$FILENAME" == *.tgz ]]; then
    tar -xzf "$FILENAME" || { echo "Error: Failed to extract tar archive '$FILENAME'." >&2; popd > /dev/null; exit 1; }
elif [[ "$FILENAME" == *.zip ]]; then
    unzip -q "$FILENAME" || { echo "Error: Failed to extract zip archive '$FILENAME'." >&2; popd > /dev/null; exit 1; }
else
    echo "Error: Unsupported archive format '$FILENAME'. Only .tar.gz, .tgz, and .zip are supported." >&2
    popd > /dev/null # Go back before exiting
    exit 1
fi

popd > /dev/null # Go back to original directory
echo "Extraction complete."

# Find the target binary within the extracted files
# Use find - it handles nested directories automatically
# -print -quit ensures we only get the first match if there are multiple
EXTRACTED_BINARY_PATH=$(find "$TMPDIR" -name "$TARGET_BINARY" -type f -executable -print -quit)

# If not found as executable, try finding any file with that name
if [[ -z "$EXTRACTED_BINARY_PATH" ]]; then
    echo "Warning: Could not find executable file named '$TARGET_BINARY'. Searching for any file named '$TARGET_BINARY'..."
    EXTRACTED_BINARY_PATH=$(find "$TMPDIR" -name "$TARGET_BINARY" -type f -print -quit)
fi

if [[ -z "$EXTRACTED_BINARY_PATH" ]]; then
    echo "Error: Could not find '$TARGET_BINARY' within the extracted archive." >&2
    echo "Contents of temporary directory ($TMPDIR):" >&2
    ls -lR "$TMPDIR" >&2
    exit 1
fi

echo "Found binary at: $EXTRACTED_BINARY_PATH"

# Check if sudo is needed for installation
SUDO_CMD=""
if [[ ! -w "$INSTALL_DIR" ]]; then
    # Check if we are already root
    if [[ "$(id -u)" != "0" ]]; then
        echo "Installation directory '$INSTALL_DIR' requires root privileges."
        if command -v sudo >/dev/null 2>&1; then
            SUDO_CMD="sudo"
            # Test sudo credentials early
            $SUDO_CMD -v || { echo "Error: sudo authentication failed."; exit 1; }
        else
            echo "Error: sudo command not found, but needed to write to $INSTALL_DIR" >&2
            exit 1
        fi
    fi
# else: we have write permissions (or are root), no sudo needed
fi

# Install the binary
INSTALL_TARGET="$INSTALL_DIR/$TARGET_BINARY"
echo "Installing '$TARGET_BINARY' to '$INSTALL_TARGET'..."
# Ensure the install directory exists
$SUDO_CMD mkdir -p "$INSTALL_DIR" || { echo "Error: Failed to create installation directory '$INSTALL_DIR'."; exit 1; }
# Move the binary
$SUDO_CMD mv "$EXTRACTED_BINARY_PATH" "$INSTALL_TARGET" || { echo "Error: Failed to move binary to '$INSTALL_TARGET'."; exit 1; }
# Ensure it's executable
$SUDO_CMD chmod +x "$INSTALL_TARGET" || { echo "Error: Failed to set execute permissions on '$INSTALL_TARGET'."; exit 1; }

echo ""
echo "Successfully installed '$TARGET_BINARY' to '$INSTALL_TARGET'."

# Optional: Check if the command is now in PATH
if command -v "$TARGET_BINARY" >/dev/null 2>&1; then
    INSTALLED_PATH=$(command -v "$TARGET_BINARY")
    if [[ "$INSTALLED_PATH" == "$INSTALL_TARGET" ]]; then
      echo "'$TARGET_BINARY' is now available in your PATH ($INSTALLED_PATH)."
      # You could optionally run a version command here if you knew it, e.g.:
      # echo "Running '$TARGET_BINARY --version':"
      # "$TARGET_BINARY" --version
    else
      echo "Note: A different version of '$TARGET_BINARY' exists in your PATH at '$INSTALLED_PATH'."
      echo "The newly installed version is at '$INSTALL_TARGET'."
    fi
else
    echo "Note: '$INSTALL_DIR' might not be in your system's PATH."
    echo "You may need to add it to your PATH or run the command using '$INSTALL_TARGET'."
fi

# Cleanup is handled by the trap

exit 0
