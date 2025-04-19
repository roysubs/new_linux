#!/usr/bin/env bash

set -e

REPO="o2sh/onefetch"
ARCH="x86_64"
OS="linux"
INSTALL_DIR="/usr/local/bin"
TMPDIR=$(mktemp -d)

# Function to get latest version
get_latest_version() {
    curl -s "https://api.github.com/repos/$REPO/releases/latest" \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^"]+)".*/\1/' \
    | sed 's/^v//'  # remove leading v if present
}

# Check for existing onefetch and its version
if command -v onefetch >/dev/null 2>&1; then
    CURRENT_VERSION=$(onefetch --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    echo "Installed onefetch version: $CURRENT_VERSION"
else
    CURRENT_VERSION="none"
    echo "onefetch not found in PATH."
fi

LATEST_VERSION=$(get_latest_version)
echo "Latest onefetch version on GitHub: $LATEST_VERSION"

if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    echo "You already have the latest version. Running onefetch:"
    onefetch
    exit 0
fi

# Download and install latest
echo "Updating onefetch to version $LATEST_VERSION..."

TAR_URL="https://github.com/$REPO/releases/download/v$LATEST_VERSION/onefetch-$LATEST_VERSION-$ARCH-$OS.tar.gz"
FILENAME=$(basename "$TAR_URL")

echo "Downloading $FILENAME..."
curl -L "$TAR_URL" -o "$TMPDIR/$FILENAME"

echo "Extracting..."
tar -xzf "$TMPDIR/$FILENAME" -C "$TMPDIR"

echo "Installing onefetch to $INSTALL_DIR..."
sudo mv "$TMPDIR/onefetch" "$INSTALL_DIR/onefetch"
sudo chmod +x "$INSTALL_DIR/onefetch"

echo "Cleaning up..."
rm -rf "$TMPDIR"

echo "Running onefetch:"
onefetch

