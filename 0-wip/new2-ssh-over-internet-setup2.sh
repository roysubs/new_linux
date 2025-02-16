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
SSH_PORT=2222  # Default SSH port for external access
LOCAL_NETWORK="192.168.0.0/24"  # Local network CIDR for allowing password authentication
UFW_RULE_NAME="Allow SSH"

# Update and install required packages
echo "Updating package lists and installing required packages..."
apt-get update -y
apt-get install -y openssh-server ufw

# Configure SSH
SSH_CONFIG="/etc/ssh/sshd_config"
echo "Configuring SSH..."

# Ensure the SSH configuration has no duplicate or conflicting settings
sed -i '/^#*Port /c\Port 22\nPort '$SSH_PORT $SSH_CONFIG
sed -i '/^#*PermitRootLogin /c\PermitRootLogin no' $SSH_CONFIG
sed -i '/^#*PubkeyAuthentication /c\PubkeyAuthentication yes' $SSH_CONFIG
sed -i '/^#*PasswordAuthentication /c\PasswordAuthentication no' $SSH_CONFIG

# Add Match block for local network password authentication
if ! grep -q "^Match Address $LOCAL_NETWORK" $SSH_CONFIG; then
  cat <<EOF >>$SSH_CONFIG

# Allow password authentication for local network
Match Address $LOCAL_NETWORK
    PasswordAuthentication yes
EOF
fi

# Restart SSH to apply changes
echo "Restarting SSH service..."
systemctl restart sshd

# Explain SSH configuration changes to the user
echo -e "\nSSH Configuration Summary:\n"
echo "- SSH listens on ports 22 and $SSH_PORT."
echo "- Password authentication is disabled globally, except for the local network ($LOCAL_NETWORK)."
echo "- Key-based authentication is required for external connections."
echo -e "\n# To enforce strong passwords, uncomment the following settings in $SSH_CONFIG:\n"
echo -e "# PasswordAuthentication no\n# Match Address $LOCAL_NETWORK\n#     PasswordAuthentication yes\n"

# Configure UFW
echo "Configuring UFW..."
ufw allow 22/tcp comment "$UFW_RULE_NAME"
ufw allow $SSH_PORT/tcp comment "$UFW_RULE_NAME"

# Display UFW rules before enabling
echo -e "\nUFW Rules Preview:\n"
ufw status numbered

# Prompt user to enable UFW
echo -e "\033[31mWARNING: Enabling UFW will lock down all ports except those explicitly allowed (22 and $SSH_PORT).\033[0m"
read -p "Do you want to enable UFW? Type 'yes' to proceed: " CONFIRM
if [[ "$CONFIRM" == "yes" ]]; then
  ufw --force enable
  echo "UFW has been enabled with the following rules:"
  ufw status verbose
else
  echo "UFW setup aborted. You can enable it later using: ufw enable"
fi

# Output public IP address
echo "Retrieving public IP address..."
PUBLIC_IP=$(curl -s ifconfig.me || echo "Unavailable")
echo "Public IP address of this server: $PUBLIC_IP"

# Instructions for router configuration
echo -e "\nManual steps for router configuration:\n"
echo "1. Log in to the router's administrative interface."
echo "2. Find the port forwarding or virtual server settings."
echo "3. Add a rule to forward external port $SSH_PORT to this server's local IP address on port $SSH_PORT."
echo "4. Save and apply the settings."

echo "Setup complete. Ensure port forwarding is configured on both routers."

# Security best practices
echo -e "\nAdditional security recommendations:\n"
echo "1. Use key-based authentication instead of passwords."
echo "   Generate keys with: ssh-keygen -t ed25519"
echo "   Copy the public key to the other server with: ssh-copy-id -p $SSH_PORT user@<server-ip>"
echo "2. Install and configure fail2ban to protect against brute-force attacks."
echo "3. Regularly update both servers: apt-get update && apt-get upgrade"
echo "4. Consider disabling password authentication once key-based authentication is set up."

