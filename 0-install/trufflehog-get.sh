#!/bin/bash
set -e

# Set constants
TMP_DIR="$(mktemp -d)"
INSTALL_DIR="$HOME/.local/bin"
ARCH="linux_amd64"

# Get latest release tag from GitHub API
LATEST_TAG=$(curl -s https://api.github.com/repos/trufflesecurity/trufflehog/releases/latest |
  grep '"tag_name":' | cut -d'"' -f4)

# Construct the tarball name and URL
TARBALL="trufflehog_${LATEST_TAG#v}_${ARCH}.tar.gz"
URL="https://github.com/trufflesecurity/trufflehog/releases/download/${LATEST_TAG}/${TARBALL}"

# Download and extract
echo "Downloading $URL..."
curl -L "$URL" -o "$TMP_DIR/$TARBALL"
tar -xzf "$TMP_DIR/$TARBALL" -C "$TMP_DIR"

# Move binary to ~/.local/bin
mkdir -p "$INSTALL_DIR"
mv "$TMP_DIR/trufflehog" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/trufflehog"

# Ensure ~/.local/bin is in PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  export PATH="$HOME/.local/bin:$PATH"
fi

# Verify install
if ! command -v trufflehog >/dev/null; then
  echo "❌ trufflehog not found on PATH"
  exit 1
else
  echo "✅ trufflehog installed successfully: $(trufflehog --version)"
fi

