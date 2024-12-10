#!/bin/bash

# Update the system
echo "Updating the system..."
sudo apt update && sudo apt upgrade -y

# Install necessary packages for OpenSSH, XRDP, and TigerVNC
echo "Install XRDP..."
sudo apt install -y xrdp

# Configure XRDP
echo "Configuring XRDP to use the MATE session..."
echo "mate-session" > ~/.xsession
sudo systemctl restart xrdp
sudo systemctl enable xrdp
echo "XRDP is set up. You can access the system via RDP using 'Remote Desktop Connection' with IP: your_ip"

