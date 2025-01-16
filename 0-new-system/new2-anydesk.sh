#!/bin/bash

# This script installs AnyDesk on an Ubuntu-based system (Ubuntu 22.04 or 24.04)
# It covers both the binary installation and repository installation methods.

# Step 1: Download the AnyDesk Deb package
# Download the AnyDesk Deb binary package from the official website.
# Note: This will require user interaction to confirm the file download.
echo "Please download the AnyDesk Deb package from: https://anydesk.com/en/downloads"
echo "Download the file meant for Ubuntu/Debian Linux and place it in your Downloads folder."

# Step 2: Install the AnyDesk Linux binary
# Change to the Downloads directory and check if the file exists.
cd ~/Downloads
echo "Checking for AnyDesk package in Downloads folder..."
ls

# Install the AnyDesk binary package.
# Ensure the filename matches your downloaded file (replace with the actual filename).
echo "Installing AnyDesk from the downloaded package..."
sudo apt install ./*.deb

# Step 3: Integrate GPG Key for the repository
# Add the GPG key to verify the authenticity of the AnyDesk repository.
echo "Integrating GPG key for AnyDesk repository..."
wget -qO - https://keys.anydesk.com/repos/DEB-GPG-KEY | sudo gpg --dearmor -o /etc/apt/keyrings/anydesk.gpg

# Step 4: Add AnyDesk Repository
# Add the official AnyDesk repository to the APT sources list.
echo "Adding AnyDesk repository to system..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/anydesk.gpg] http://deb.anydesk.com/ all main" | sudo tee /etc/apt/sources.list.d/anydesk.list > /dev/null

# Step 5: Update Apt Repository Cache
# Update the system package list to include the newly added AnyDesk repository.
echo "Updating apt repository cache..."
sudo apt update

# Step 6: Install AnyDesk via the repository
# Install AnyDesk using the repository.
echo "Installing AnyDesk..."
sudo apt install -y anydesk

# Step 7: Run AnyDesk
# Check if AnyDesk is running, if not, start it.
echo "Checking AnyDesk service status..."
sudo systemctl status anydesk --no-pager -l

# If the service isn't running, start it manually.
echo "Starting AnyDesk if not already running..."
sudo systemctl start anydesk

# Step 8: Uninstall AnyDesk (Optional)
# If you want to uninstall AnyDesk, use the following commands:
# Uninstall AnyDesk and remove its repository.
echo "If you want to uninstall AnyDesk, use the following commands:"
echo "sudo apt remove anydesk"
echo "sudo rm /etc/apt/sources.list.d/anydesk-stable.list"

