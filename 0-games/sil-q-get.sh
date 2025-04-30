#!/bin/bash
set -e

REPO="sil-quirk/sil-q"
INSTALL_DIR="$HOME/games/sil-q"
BIN_DIR="$HOME/bin"
SYMLINK="$BIN_DIR/sil-q"

echo "📦 Fetching latest release info from GitHub..."
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
TARBALL_URL=$(curl -s "$API_URL" | grep tarball_url | cut -d '"' -f 4)
if [[ -z "$TARBALL_URL" ]]; then
    echo "❌ Failed to get tarball URL."
    exit 1
fi

echo "✅ Downloading from: $TARBALL_URL"
TMP_DIR=$(mktemp -d)
echo "⬇️ Downloading and extracting source..."
curl -L "$TARBALL_URL" | tar -xz -C "$TMP_DIR" --strip-components=1

cd "$TMP_DIR/src"
echo "🛠️ Preparing Makefile..."
# Enable terminal (GCU) and disable other frontends
sed -i 's/^#\(.*USE_GCU.*\)/\1/' Makefile.std
sed -i 's/^\(.*USE_X11.*\)/#\1/' Makefile.std
sed -i 's/^\(.*USE_SDL.*\)/#\1/' Makefile.std

# Remove macOS-specific flags
sed -i 's/-arch [^ ]*//g' Makefile.std

echo "⚙️ Building with GCU terminal backend..."
make -f Makefile.std install

echo "📁 Installing to: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r ../* "$INSTALL_DIR"

echo "🔗 Creating symlink at: $SYMLINK"
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/sil" "$SYMLINK"

echo "✅ Done! You can now run Sil-Q with:

    sil-q

💡 If '~/bin' is not on your PATH, add this to ~/.bashrc or ~/.zshrc:

    export PATH=\"\$HOME/bin:\$PATH\"
"

