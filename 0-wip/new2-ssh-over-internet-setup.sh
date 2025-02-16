#!/bin/bash

# Automates the setup of SSH communication between two Debian servers over the internet.
# Run this script on both servers. Manual steps for router configuration are detailed below.
# Setup and enable UFW
# Manual configuration of port forwarding is required on each router
# For additional security, consider running SSH on a non-standard port (already suggested in
# the script) and setting up key-based authentication.

set -e

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then echo "This script must be run as root."; exit 1; fi

# Variables
SSH_PORT=2222  # Default SSH port (change to 22 if preferred, or choose a custom port for security)
UFW_RULE_NAME="Allow SSH"

# Update and install required packages
echo "Updating package lists and installing required packages..."
apt-get update -y
apt-get install -y openssh-server ufw

# Configure SSH
SSH_CONFIG="/etc/ssh/sshd_config"
echo "Configuring SSH..."
sed -i "/^#*Port /c\Port $SSH_PORT" $SSH_CONFIG  # Set custom SSH port
sed -i '/^#*PermitRootLogin /c\PermitRootLogin no' $SSH_CONFIG  # Disable root login
sed -i '/^#*PasswordAuthentication /c\PasswordAuthentication yes' $SSH_CONFIG  # Enable password authentication
sed -i '/^#*AllowTcpForwarding /c\AllowTcpForwarding no' $SSH_CONFIG  # Disable TCP forwarding
sed -i '/^#*X11Forwarding /c\X11Forwarding no' $SSH_CONFIG  # Disable X11 forwarding
systemctl restart sshd

# Configure UFW (Uncomplicated Firewall)
echo "Configuring UFW..."
ufw allow $SSH_PORT/tcp comment "$UFW_RULE_NAME"
ufw --force enable
ufw status verbose

# Output public IP address
echo "Retrieving public IP address..."
PUBLIC_IP=$(curl -s ifconfig.me)
echo "Public IP address of this server: $PUBLIC_IP"

# Instructions for router configuration
echo "Manual steps for router configuration:"
echo "1. Log in to the router's administrative interface."
echo "2. Find the port forwarding or virtual server settings."
echo "3. Add a rule to forward external port $SSH_PORT to this server's local IP address on port $SSH_PORT."
echo "4. Save and apply the settings."

echo "Setup complete. Ensure port forwarding is configured on both routers."

# Security best practices
echo "Additional security recommendations:"
echo "1. Use key-based authentication instead of passwords."
echo "   Generate keys with: ssh-keygen -t ed25519"
echo "   Copy the public key to the other server with: ssh-copy-id -p $SSH_PORT user@<server-ip>"
echo "2. Install and configure fail2ban to protect against brute-force attacks."
echo "3. Regularly update both servers: apt-get update && apt-get upgrade"
echo "4. Consider disabling password authentication once key-based authentication is set up."

