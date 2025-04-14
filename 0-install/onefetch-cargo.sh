#!/bin/bash

set -e

# === Config ===
KNOWN_GOOD_VERSION="2.23.0"

# === Elevate if needed ===
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo "$0" "$@"
fi

# === Dependencies ===
echo ""
if ! command -v cmake >/dev/null 2>&1; then
    echo "Installing cmake..."
    apt update && apt install -y cmake
else
    echo -e "\033[32m✅ cmake already installed.\033[0m"
fi

if ! command -v cargo >/dev/null 2>&1; then
    echo -e "\n\033[33mRust (cargo) is required to install onefetch.\033[0m"
    read -p "Would you like to install Rust and Cargo now? (Y/n): " yn
    yn=${yn:-Y}
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    else
        echo "Cannot continue without cargo. Exiting."
        exit 1
    fi
else
    echo -e "\033[32m✅ cargo is already installed.\033[0m"
fi

# === Get current and latest versions ===
INSTALLED_VER=$(cargo install --list 2>/dev/null | grep -E '^onefetch v' | awk '{print $2}')
LATEST_VER=$(curl -s https://crates.io/api/v1/crates/onefetch | jq -r '.crate.max_stable_version')

echo -e "\nInstalled version: ${INSTALLED_VER:-none}"
echo -e "Latest version on crates.io: $LATEST_VER"

# === Logic ===
USE_BETA=false
if [[ "$1" == "--beta" ]]; then
    USE_BETA=true
fi

if ! $USE_BETA; then
    if [[ "$INSTALLED_VER" == "$KNOWN_GOOD_VERSION" ]]; then
        echo -e "\n\033[34m⏩ onefetch is already at known good version ($KNOWN_GOOD_VERSION). No action taken.\033[0m"
        exit 0
    else
        echo -e "\n🔄 Installing known good version: $KNOWN_GOOD_VERSION..."
        cargo install onefetch --version "$KNOWN_GOOD_VERSION" --force
    fi
else
    echo -e "\n⚠️  Beta mode enabled: installing latest version $LATEST_VER (may be unstable)"
    cargo install onefetch --version "$LATEST_VER" --force
fi

# === Final check ===
if command -v onefetch >/dev/null 2>&1; then
    echo -e "\n\033[32m✅ onefetch installation complete.\033[0m"
    onefetch --version
else
    echo -e "\n\033[31m❌ onefetch installation failed.\033[0m"
    exit 1
fi

