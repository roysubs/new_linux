#!/bin/bash

# Update package lists and install necessary components
echo "Updating package lists..."
sudo apt update

# Install necessary components for X11 forwarding
echo "Installing necessary X11 components..."
sudo apt install -y xauth xorg openbox xclip

# Install the OpenSSH server if not already installed (needed for SSH connection)
echo "Installing OpenSSH server..."
sudo apt install -y openssh-server

# Enable X11 forwarding in SSH configuration
echo "Enabling X11 forwarding in SSH configuration..."

# Backup the original sshd_config before modifying
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Enable X11 forwarding in the SSH config file
sudo sed -i 's/#X11Forwarding no/X11Forwarding yes/' /etc/ssh/sshd_config
sudo sed -i 's/X11DisplayOffset 10/X11DisplayOffset 10/' /etc/ssh/sshd_config
sudo sed -i 's/#X11UseLocalhost yes/X11UseLocalhost yes/' /etc/ssh/sshd_config

# Restart SSH service to apply changes
echo "Restarting SSH service to apply changes..."
sudo systemctl restart ssh

# Check if the X11 display server is installed and running
echo "Checking if X11 display server is running..."
if ! pgrep -x "Xorg" > /dev/null; then
  echo "Xorg is not running. Starting Xorg server..."
  startx &
else
  echo "Xorg is already running."
fi

# Summary and instructions for the user
echo ""
echo "X11 forwarding has been enabled on this system. Here are the changes that were made:"
echo "1. Installed the required X11 packages: xauth, xorg, openbox, and xclip."
echo "2. Configured the SSH server to allow X11 forwarding by modifying the sshd_config file."
echo "3. Restarted the SSH service to apply changes."
echo "4. Checked if the Xorg display server is running and started it if necessary."
echo ""
echo "### How to use X11 forwarding and xclip ###"
echo ""
echo "1. To use X11 forwarding, connect to this system via SSH from a client with an X11 server running."
echo "   For example, use the following command from your client system (replace [user] and [host]):"
echo "     ssh -X [user]@[host]"
echo ""
echo "2. Once connected, you can use X11 applications as if they were running locally."
echo "   For instance, you can run xclock to test X11 forwarding:"
echo "     xclock"
echo ""
echo "3. To copy text from this system's clipboard to the Windows clipboard, you can use xclip."
echo "   For example, to copy the contents of a script to the clipboard, use:"
echo "     cat /path/to/your/script.sh | xclip -selection clipboard"
echo "   This will send the contents of the script to the clipboard of the machine you're SSHing from."
echo ""
echo "That's it! X11 forwarding and clipboard copy should now work seamlessly between your systems."

