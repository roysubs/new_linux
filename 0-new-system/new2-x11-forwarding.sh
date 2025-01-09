#!/bin/bash

# Check if the script is run as root or with sudo
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root or with sudo."
  exit 1
fi

echo "- Check and configure SSH server for X11 Forwarding..."

# Ensure SSH is installed
if ! command -v ssh &>/dev/null; then
    echo "SSH server is not installed. Installing OpenSSH server..."
    apt update && apt install -y openssh-server
else
    echo "SSH server is already installed."
fi

# Update /etc/ssh/sshd_config
echo "- Check and configure /etc/ssh/sshd_config"
# Do not need to uncomment Port 22. SSH servers listen on port 22 by default so that is assumed; only uncheck the Port 22 line for specific security purposes.
sed -i 's/^#X11Forwarding.*/X11Forwarding yes/' /etc/ssh/sshd_config 
sed -i 's/^#X11DisplayOffset.*/X11DisplayOffset 10/' /etc/ssh/sshd_config
sed -i 's/^#X11UseLocalhost.*/X11UseLocalhost yes/' /etc/ssh/sshd_config

# Open Port 22 in the firewall
echo "- Ensure Port 22 is open for SSH..."
ufw allow 22/tcp || iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Restart SSH server
echo "- Restarting SSH service to apply changes..."
systemctl restart sshd

echo "SSH server configured for X11 Forwarding. Moving to display configuration."

# Ensure xauth is installed
if ! command -v xauth &>/dev/null; then
    echo "Installing xauth for X11 authentication..."
    apt update && apt install -y xauth
else
    echo "xauth is already installed."
fi

echo "Configuration complete. Your Debian server is ready for X11 Forwarding."
echo
echo "
Following steps are for Windows client-side setup:

Install X Server on Windows:
Download and install an X Server, such as Xming or VcXsrv.
Launch the X Server with "Enable Public Access" and "Disable Access Control" for simplicity.

Configure SSH Client (e.g., PuTTY or OpenSSH built into Windows 10/11):

PuTTY Configuration:
Go to the \"SSH\" -> \"X11\" section in PuTTY's settings.
Check \"Enable X11 Forwarding.\"
Set \"X display location\" to localhost:0.0.
Save the settings and connect to your Debian server.
OpenSSH (Windows Terminal):

Ensure the OpenSSH client is installed (ssh -V to check).
Use the command:
ssh -X user@your-debian-server
"
