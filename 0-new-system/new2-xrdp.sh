#!/bin/bash

# Update the system and install required package
echo "Updating the system..."
sudo apt update && sudo apt upgrade -y
echo "Install XRDP..."
sudo apt install -y xrdp

# Configure XRDP
echo "Configuring XRDP to use the MATE session..."
echo "mate-session" > ~/.xsession
sudo systemctl restart xrdp
sudo systemctl enable xrdp
echo
echo "XRDP is set up on port 5589."
echo "From Windows, connect using 'Remote Desktop Connection' with the IP or hostname of this server."
echo "From Linux, connect using 'Remmina' or other packages that can use XRDP to connect."
echo
