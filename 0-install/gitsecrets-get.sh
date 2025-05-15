#!/bin/bash

# Set the installation directory
BIN_DIR="$HOME/.local/bin"

# Ensure the directory exists
mkdir -p "$BIN_DIR"

# Download the latest GitSecrets binary
curl -Lo "$BIN_DIR/git-secrets" https://github.com/awslabs/git-secrets/releases/latest/download/git-secrets-linux-amd64

# Make it executable
chmod +x "$BIN_DIR/git-secrets"

# Ensure the BIN_DIR is on the PATH
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo "Adding $BIN_DIR to PATH"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    source "$HOME/.bashrc"
fi

# Check if git-secrets is available
if ! command -v git-secrets &>/dev/null; then
    echo "git-secrets is not available on the PATH. Exiting..."
    exit 1
fi

# Initialize GitSecrets for the repo (run once)
git secrets --add-provider --global
git secrets --register-aws

# Run GitSecrets on staged files
git diff --cached --name-only | xargs -I {} git secrets --scan {}

