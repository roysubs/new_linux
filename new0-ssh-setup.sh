#!/bin/bash

# Update the system
echo "Updating the system..."
sudo apt update && sudo apt upgrade -y

# Install necessary packages for OpenSSH
echo "Install OpenSSH and XRDP..."
sudo apt install -y openssh-server

# Set up OpenSSH
echo "Setting up OpenSSH server..."
sudo systemctl enable ssh
sudo systemctl start ssh
echo "OpenSSH is set up. You can access the system via SSH using 'ssh username@your_ip'."
