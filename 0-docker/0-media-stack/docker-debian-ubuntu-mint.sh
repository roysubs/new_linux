#!/usr/bin/env bash
set -euo pipefail

echo "==> Universal Docker install script for Debian/Ubuntu-based distros"

# Detect architecture
ARCH=$(dpkg --print-architecture)
echo "Detected architecture: $ARCH"

# Detect distro and codename
if ! command -v lsb_release >/dev/null 2>&1; then
    echo "Error: lsb_release command not found. Please install 'lsb-release' package first."
    exit 1
fi

DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

echo "Detected distro: $DISTRO"
echo "Detected codename: $CODENAME"

# Determine Docker repo base URL depending on distro
if [[ "$DISTRO" == "ubuntu" ]] || [[ "$DISTRO" == "linuxmint" ]]; then
    # For Linux Mint, still use Ubuntu repos
    # Linux Mint codename often differs, map it to Ubuntu base if mint detected
    if [[ "$DISTRO" == "linuxmint" ]]; then
        echo "Linux Mint detected - mapping codename to Ubuntu base..."
        # Map common Mint versions to Ubuntu codenames
        case "$CODENAME" in
            una|vanessa|vera|victoria) UBUNTU_BASE="jammy" ;;
            ulyana|ulyssa|uma) UBUNTU_BASE="focal" ;;
            tessa|tara) UBUNTU_BASE="bionic" ;;
            *) 
                echo "Warning: Unknown Linux Mint codename '$CODENAME', defaulting to jammy"
                UBUNTU_BASE="jammy"
                ;;
        esac
        CODENAME=$UBUNTU_BASE
        DISTRO="ubuntu"
        echo "Using Ubuntu base codename: $CODENAME"
    fi
    DOCKER_REPO_URL="https://download.docker.com/linux/ubuntu"
elif [[ "$DISTRO" == "debian" ]]; then
    DOCKER_REPO_URL="https://download.docker.com/linux/debian"
else
    echo "Warning: Unsupported distro '$DISTRO'. This script supports Ubuntu, Linux Mint, and Debian only."
    exit 1
fi

# Create keyrings directory
sudo mkdir -p /etc/apt/keyrings

# Download Docker GPG key
echo "Downloading Docker GPG key..."
curl -fsSL "${DOCKER_REPO_URL}/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repo list file
REPO_ENTRY="deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] ${DOCKER_REPO_URL} ${CODENAME} stable"
echo "Adding Docker repository:"
echo "  $REPO_ENTRY"
echo "$REPO_ENTRY" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update and install
echo "Updating package lists..."
sudo apt update

echo "Installing Docker packages..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> Docker installation successful!"
echo "Check Docker version: docker --version"
echo "Run test container: sudo docker run hello-world"

# Test and ensure that user is in docker group
if groups "$USER" | grep -qw docker; then
  echo "User '$USER' is already in the docker group."
else
  echo "User '$USER' is NOT in the docker group. Adding now..."
  sudo usermod -aG docker "$USER"
  echo "User '$USER' has been added to the docker group."
  echo "Please log out and log back in, or reboot your system, to apply this change."
fi

