#!/bin/bash

##########
#
# Setup SSH-RDP-VNC remote access on Debian system
#
##########
# This script will install and configure OpenSSH, XRDP, and VNC on a Debian system with MATE desktop.
# It allows remote access via SSH (command-line), RDP (graphical), and VNC (graphical).
# Make sure to run this script with root privileges.

# System Update: It updates your package lists and upgrades your installed packages.
# Install Required Packages: Installs OpenSSH, XRDP, TightVNC, and MATE desktop. It also installs Remmina for Linux users who might need a client.
# OpenSSH: Configures the OpenSSH server for remote command-line access.
# XRDP: Configures XRDP to use the MATE session, allowing you to connect via Remote Desktop Protocol (RDP).
# VNC: Configures TightVNC for graphical remote access. It sets up the MATE session for VNC and starts the server.
# Firewall Configuration: Opens the required ports for SSH (22), RDP (3389), and VNC (5901) using ufw (Uncomplicated Firewall).
# Completion: Displays a message with instructions on how to access the system via SSH, RDP, and VNC.

# To Run the Script:
# chmod +x setup_remote_access.sh   # Make the script executable
# sudo ./setup_remote_access.sh     # Run the script as root or with sudo
# SSH: use ssh username@your_ip to connect from remote system
# RDP: connect from Windows or Linux RDP client (Remmina) to the IP of your Debian machine.
# VNC: use a VNC client to connect to your Debian machine. The address will be your_ip:1.
#      The vncserver command is interactive, prompting you to set up a password. Once done, it starts the
#      VNC server, and you can connect to it on port 5901 (e.g., your_ip:1).
#      To change the VNC password, run:   vncpasswd

# Updating the system
echo "Updating the system..."
sudo apt update && sudo apt upgrade -y

# Install the MATE meta package (to install all MATE components)
# sudo apt install -y task-mate-desktop

# Install necessary packages for OpenSSH, XRDP, and VNC
echo "Installing OpenSSH, XRDP, and TightVNC server..."
sudo apt install -y openssh-server xrdp tightvncserver

# Optional, install Remmina (RDP/VNC client for Linux) and TightVNC as clients for testing
# echo "Installing Remmina (optional, if you need a client to test remote access)..."
# sudo apt install -y remmina tightvnc

# Ensure OpenSSH server is installed and running
echo "Setting up OpenSSH server..."
sudo systemctl enable ssh
sudo systemctl start ssh
sudo systemctl status ssh
echo "OpenSSH is set up. You can access the system via SSH using 'ssh username@your_ip'."

# Configure XRDP (RDP) to use MATE session
echo "Configuring XRDP to use the MATE session..."

# Create or edit the xsession file for XRDP to start the MATE session
echo "mate-session" > ~/.xsession

# Restart XRDP to apply the changes
sudo systemctl restart xrdp
echo "XRDP is set up. You can access the system via RDP using 'Remote Desktop Connection' with IP: your_ip"

# Ensure XRDP service is enabled on boot
sudo systemctl enable xrdp

# Set up TightVNC for additional graphical access
echo "Configuring TightVNC..."

# Set up the VNC password (this will be prompted interactively)
vncserver

# Kill the VNC server to edit the xstartup file
vncserver -kill :1

# Create the xstartup file to use MATE session
echo "#!/bin/sh" > ~/.vnc/xstartup
echo "export XDG_SESSION_TYPE=x11" >> ~/.vnc/xstartup
echo "mate-session &" >> ~/.vnc/xstartup

# Make the xstartup file executable
chmod +x ~/.vnc/xstartup

# Start the VNC server again
vncserver
echo "VNC is set up. You can access the system via VNC using a VNC client with IP: your_ip:1"

# Optional: Open necessary firewall ports for SSH (22), XRDP (3389), and VNC (5901)
echo "Configuring firewall to allow SSH, XRDP, and VNC connections..."

# Allow SSH, XRDP, and VNC in the firewall
sudo ufw allow ssh
sudo ufw allow 3389/tcp  # XRDP
sudo ufw allow 5901/tcp  # VNC

# Enable UFW firewall (if it's not already enabled)
sudo ufw enable

echo "Firewall has been configured. SSH, RDP, and VNC ports are open."

# Final message
echo "Remote access is now configured. You can access your Debian system via:"
echo " - SSH: ssh username@your_ip"
echo " - RDP: Remote Desktop Connection (use IP: your_ip)"
echo " - VNC: VNC Client (use IP: your_ip:1)"
echo "Please replace 'your_ip' with the actual IP address of your Debian system."

echo "Script completed successfully!"
echo ""
