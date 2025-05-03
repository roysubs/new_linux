#!/bin/bash

# Scrape git-credential-manager repo for latest releases, then download and install with dpkg

# git-credential-manager --version
# git-credential-manager configure

# Uninstall GCM
# git-credential-manager unconfigure
# sudo dpkg -r gcm

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to install Git Credential Manager using .deb package from GitHub release page
install_deb_package_from_github() {
  echo "Fetching the latest Git Credential Manager release..."

  # Define the GitHub API URL for the latest release of Git Credential Manager
  api_url="https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest"

  # Check if jq is installed; if not, install it
  if ! command_exists jq; then
    echo "jq is not installed. Installing jq..."
    sudo apt update
    sudo apt install -y jq
  fi

  # Use curl to fetch the latest release information from GitHub API and jq to extract the .deb URL
  deb_url=$(curl -s "$api_url" | jq -r '.assets[] | select(.name | test(".deb$")) | .browser_download_url')

  if [ -z "$deb_url" ]; then
    echo "Error: Could not find the .deb package URL."
    exit 1
  fi

  # Download the .deb package
  echo "Downloading the .deb package from $deb_url..."
  curl -L "$deb_url" -o gcm.deb

  # Install the .deb package
  echo "Installing Git Credential Manager..."
  sudo dpkg -i gcm.deb

  # Clean up the downloaded .deb package
  rm gcm.deb

  # Configure Git Credential Manager
  git-credential-manager configure
}

# Function to uninstall Git Credential Manager
uninstall_gcm() {
  echo "Uninstalling Git Credential Manager..."
  git-credential-manager unconfigure
  sudo dpkg -r gcm 2>/dev/null || true
  sudo rm -f $(command -v git-credential-manager) 2>/dev/null || true
  echo "Git Credential Manager uninstalled successfully."
}

# Menu for the user to choose the installation method
echo "Choose an option:"
echo "1. Install Git Credential Manager"
echo "2. Uninstall Git Credential Manager"
read -p "Enter your choice (1/2): " choice

case "$choice" in
  1)
    install_deb_package_from_github
    ;;
  2)
    uninstall_gcm
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

echo "Operation completed."

