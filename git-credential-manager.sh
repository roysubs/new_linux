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

# Function to install Git Credential Manager using tarball
install_tarball() {
  echo "Installing Git Credential Manager using tarball..."
  read -p "Enter the path to the tarball: " tarball_path
  if [ -f "$tarball_path" ]; then
    sudo tar -xvf "$tarball_path" -C /usr/local/bin
    git-credential-manager configure
  else
    echo "The tarball path does not exist. Aborting."
    exit 1
  fi
}

# Function to install Git Credential Manager using source helper script
install_source_script() {
  echo "Installing Git Credential Manager using source helper script..."
  if ! command_exists curl; then
    echo "curl is not installed. Installing curl..."
    sudo apt update
    sudo apt install -y curl
  fi
  echo "Downloading and running the source helper script..."
  curl -L https://aka.ms/gcm/linux-install-source.sh | sh
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
echo "Choose the installation method:"
echo "1. Install via .deb package from GitHub release"
echo "2. Install via tarball"
echo "3. Install via source helper script"
echo "4. Uninstall Git Credential Manager"
read -p "Enter your choice (1/2/3/4): " choice

case "$choice" in
  1)
    install_deb_package_from_github
    ;;
  2)
    install_tarball
    ;;
  3)
    install_source_script
    ;;
  4)
    uninstall_gcm
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

echo "Operation completed."

