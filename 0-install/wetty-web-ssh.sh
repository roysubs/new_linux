#!/bin/bash

# Script to install WeTTY (Web TTY) on Debian

# --- Configuration ---
WETTY_USER="wetty"         # Dedicated user to run WeTTY
WETTY_PORT="3000"          # Default port WeTTY will listen on
INSTALL_NODE_VERSION="20"  # Major version of Node.js to install from NodeSource

# --- Helper Functions ---
echoinfo() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

echowarn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

echoerror() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

check_command_success() {
    if [ $? -ne 0 ]; then
        echoerror "$1 failed. Exiting."
        exit 1
    fi
}

# --- Pre-flight Checks ---
if [ "$(id -u)" -ne 0 ]; then
  echoerror "This script must be run as root or with sudo privileges."
  exit 1
fi

# --- Start Installation ---
echoinfo "Starting WeTTY installation process..."

# 1. Update system
echoinfo "Updating package lists and upgrading existing packages..."
sudo apt update -y && sudo apt upgrade -y
check_command_success "System update/upgrade"

# 2. Install essential dependencies
echoinfo "Installing prerequisites: curl, gpg, build-essential, python, git..."
sudo apt install -y curl gpg build-essential python3 git
check_command_success "Prerequisite installation (curl, gpg, build-essential, python, git)"

# 3. Install Node.js and npm from NodeSource (for a more up-to-date version)
echoinfo "Setting up NodeSource repository for Node.js v$INSTALL_NODE_VERSION.x..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
check_command_success "Adding NodeSource GPG key"

echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$INSTALL_NODE_VERSION.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
check_command_success "Adding NodeSource repository"

echoinfo "Updating package lists after adding NodeSource..."
sudo apt update -y
check_command_success "Package list update after NodeSource"

echoinfo "Installing Node.js v$INSTALL_NODE_VERSION.x and npm..."
sudo apt install -y nodejs
check_command_success "Node.js and npm installation"

echoinfo "Verifying Node.js and npm installation..."
node -v
check_command_success "Node.js version check"
npm -v
check_command_success "npm version check"

# 4. Install WeTTY globally using npm
echoinfo "Installing WeTTY globally using npm..."
sudo npm install -g wetty
check_command_success "WeTTY global installation via npm"

echoinfo "Verifying WeTTY installation..."
if ! command -v wetty &> /dev/null; then
    echoerror "WeTTY command could not be found after installation. This might indicate an issue with the npm global path."
    echoerror "Please check your PATH environment variable and npm global configuration."
    # Attempt to find where npm installs global packages
    NPM_GLOBAL_PATH=$(npm root -g)
    echoerror "NPM global modules are typically in: $NPM_GLOBAL_PATH"
    echoerror "If wetty is in a subdirectory like '$NPM_GLOBAL_PATH/wetty/bin/wetty', ensure the parent bin directory is in your PATH."
    exit 1
fi
wetty --version
check_command_success "WeTTY version check"
WETTY_INSTALL_PATH=$(command -v wetty)
echoinfo "WeTTY installed at: $WETTY_INSTALL_PATH"


# 5. Create a dedicated user for WeTTY (Optional but Recommended)
if id "$WETTY_USER" &>/dev/null; then
    echoinfo "User '$WETTY_USER' already exists."
else
    echoinfo "Creating user '$WETTY_USER' to run WeTTY..."
    # Create a system user without a home directory, or a regular user if you prefer
    sudo useradd -r -s /bin/false "$WETTY_USER"
    # If you want a home directory (e.g., for logs or configs managed by this user):
    # sudo useradd -m -s /bin/bash "$WETTY_USER"
    check_command_success "WeTTY user creation"
fi

# --- Post-Installation Instructions ---
echoinfo "WeTTY installation complete!"
echowarn "---------------------------------------------------------------------"
echowarn "IMPORTANT NEXT STEPS:"
echowarn "---------------------------------------------------------------------"
echo ""
echoinfo "1. Running WeTTY manually:"
echo "   You can start WeTTY with various options. For example:"
echo "   To allow connections to SSH on the local machine for any user:"
echo "     wetty -p $WETTY_PORT"
echo ""
echo "   To connect to a specific SSH server and user (prompts for password in browser):"
echo "     wetty -p $WETTY_PORT --ssh-host your.ssh.server.com --ssh-user your_ssh_username"
echo ""
echo "   To allow connections only from localhost (e.g., if behind a reverse proxy):"
echo "     wetty --host 127.0.0.1 -p $WETTY_PORT"
echo ""
echo "   For more options, run:"
echo "     wetty --help"
echo ""
echoinfo "2. Access WeTTY:"
echo "   Open your web browser and go to: http://YOUR_SERVER_IP:$WETTY_PORT"
echo "   (Replace YOUR_SERVER_IP with your server's actual IP address)"
echo ""
echoinfo "3. Firewall:"
echo "   If you have a firewall (like ufw), allow port $WETTY_PORT:"
echo "     sudo ufw allow $WETTY_PORT/tcp"
echo ""
echoinfo "4. Running WeTTY as a service (systemd example):"
echo "   For WeTTY to run persistently and start on boot, create a systemd service file."
echo "   Example ' /etc/systemd/system/wetty.service ':"
echo ""
echo "   [Unit]"
echo "   Description=WeTTY - Web TTY service"
echo "   After=network.target"
echo ""
echo "   [Service]"
echo "   Type=simple"
echo "   User=$WETTY_USER"
# Note: The ExecStart path might need adjustment if 'wetty' is not in the standard path for the $WETTY_USER
# You might need to use the full path obtained earlier: $WETTY_INSTALL_PATH
echo "   ExecStart=$WETTY_INSTALL_PATH -p $WETTY_PORT --ssh-host localhost" # Add other options as needed
echo "   Restart=on-failure"
# If you created WETTY_USER with a home directory and want to set WorkingDirectory:
#   WorkingDirectory=/home/$WETTY_USER
# Or a generic one:
#   WorkingDirectory=/
echo "   Environment=PATH=/usr/bin:/usr/local/bin:\$PATH" # Ensure Node's path is available
echo ""
echo "   [Install]"
echo "   WantedBy=multi-user.target"
echo ""
echo "   After creating the file, run:"
echo "     sudo systemctl daemon-reload"
echo "     sudo systemctl enable wetty.service"
echo "     sudo systemctl start wetty.service"
echo "     sudo systemctl status wetty.service"
echo ""
echoinfo "5. HTTPS / Reverse Proxy (Recommended for Security):"
echo "   For production, run WeTTY behind a reverse proxy like Nginx or Apache"
echo "   to enable HTTPS (SSL/TLS encryption)."
echo ""
echowarn "---------------------------------------------------------------------"

exit 0
