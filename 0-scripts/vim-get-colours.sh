#!/bin/bash

# Script to download and install flazz/vim-colorschemes
# and backup existing colorschemes.

# --- Configuration ---
REPO_URL="https://github.com/flazz/vim-colorschemes.git"
TMP_CLONE_DIR="/tmp/vim-colorschemes-flazz"
BACKUP_BASE_DIR="$HOME/.backup"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

VIM_COLORS_DIR="$HOME/.vim/colors"
VIM_BACKUP_DIR="$BACKUP_BASE_DIR/vim-colors-$TIMESTAMP"

NVIM_CONFIG_DIR="$HOME/.config/nvim"
NVIM_COLORS_DIR="$NVIM_CONFIG_DIR/colors"
NVIM_BACKUP_DIR="$BACKUP_BASE_DIR/nvim-colors-$TIMESTAMP"

# --- Helper Functions ---
info() {
  echo "[INFO] $1"
}

warn() {
  echo "[WARN] $1"
}

error() {
  echo "[ERROR] $1" >&2
  exit 1
}

# --- Main Script ---

info "Starting colorscheme installation process..."

# 1. Create backup base directory if it doesn't exist
if [ ! -d "$BACKUP_BASE_DIR" ]; then
  info "Creating backup directory: $BACKUP_BASE_DIR"
  mkdir -p "$BACKUP_BASE_DIR" || error "Failed to create backup directory $BACKUP_BASE_DIR"
fi

# 2. Backup existing Vim colors directory
if [ -d "$VIM_COLORS_DIR" ]; then
  info "Backing up existing Vim colors from $VIM_COLORS_DIR to $VIM_BACKUP_DIR"
  mkdir -p "$(dirname "$VIM_BACKUP_DIR")" # Ensure parent of backup dir exists
  cp -r "$VIM_COLORS_DIR" "$VIM_BACKUP_DIR" || warn "Failed to backup Vim colors directory. Continuing..."
else
  info "No existing Vim colors directory found at $VIM_COLORS_DIR. Skipping backup."
fi

# 3. Backup existing Neovim colors directory (if Neovim config exists)
if [ -d "$NVIM_CONFIG_DIR" ]; then
  if [ -d "$NVIM_COLORS_DIR" ]; then
    info "Backing up existing Neovim colors from $NVIM_COLORS_DIR to $NVIM_BACKUP_DIR"
    mkdir -p "$(dirname "$NVIM_BACKUP_DIR")" # Ensure parent of backup dir exists
    cp -r "$NVIM_COLORS_DIR" "$NVIM_BACKUP_DIR" || warn "Failed to backup Neovim colors directory. Continuing..."
  else
    info "No existing Neovim colors directory found at $NVIM_COLORS_DIR. Skipping backup."
  fi
else
  info "Neovim config directory $NVIM_CONFIG_DIR not found. Skipping Neovim steps."
fi

# 4. Clone the repository into /tmp/
info "Cloning $REPO_URL into $TMP_CLONE_DIR..."
# Remove the directory if it already exists to ensure a fresh clone
if [ -d "$TMP_CLONE_DIR" ]; then
  info "Removing existing temporary clone directory: $TMP_CLONE_DIR"
  rm -rf "$TMP_CLONE_DIR"
fi
git clone --depth 1 "$REPO_URL" "$TMP_CLONE_DIR" || error "Failed to clone repository from $REPO_URL"

# Check if cloned repo has the 'colors' subdirectory
if [ ! -d "$TMP_CLONE_DIR/colors" ]; then
  error "Cloned repository does not contain a 'colors' subdirectory at $TMP_CLONE_DIR/colors"
fi

# 5. Install for Vim
info "Installing colorschemes for Vim..."
mkdir -p "$VIM_COLORS_DIR" || error "Failed to create Vim colors directory: $VIM_COLORS_DIR"
info "Copying .vim files to $VIM_COLORS_DIR (forcing overwrite)..."
cp -f "$TMP_CLONE_DIR"/colors/*.vim "$VIM_COLORS_DIR/" || error "Failed to copy colorschemes to $VIM_COLORS_DIR"
info "Vim colorschemes installed."

# 6. Install for Neovim (if Neovim config exists)
if [ -d "$NVIM_CONFIG_DIR" ]; then
  info "Installing colorschemes for Neovim..."
  mkdir -p "$NVIM_COLORS_DIR" || error "Failed to create Neovim colors directory: $NVIM_COLORS_DIR"
  info "Copying .vim files to $NVIM_COLORS_DIR (forcing overwrite)..."
  cp -f "$TMP_CLONE_DIR"/colors/*.vim "$NVIM_COLORS_DIR/" || error "Failed to copy colorschemes to $NVIM_COLORS_DIR"
  info "Neovim colorschemes installed."
else
  info "Skipping Neovim installation as $NVIM_CONFIG_DIR was not found."
fi

# 7. Cleanup temporary clone directory
info "Cleaning up temporary clone directory: $TMP_CLONE_DIR"
rm -rf "$TMP_CLONE_DIR"

info "Colorscheme installation process completed successfully!"
echo "Your Vim theme cycler should now include themes from flazz/vim-colorschemes."
echo "Previous themes (if any) are backed up in $BACKUP_BASE_DIR"


