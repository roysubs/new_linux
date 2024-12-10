#!/bin/bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please use sudo."
   exit 1
fi

echo "Updating package lists..."
apt update

echo "Installing MATE desktop environment and necessary tools..."
apt install -y mate-desktop-environment mate-themes mate-tweak git plank mint-icons

echo "Downloading Mint-Y and Mint-X themes..."
# Clone Mint themes and install them system-wide
mkdir -p /usr/share/themes
mkdir -p /usr/share/icons

# Download themes
if [ ! -d "/usr/share/themes/mint-themes" ]; then
    git clone https://github.com/linuxmint/mint-themes.git /usr/share/themes/mint-themes
    echo "Mint themes installed."
else
    echo "Mint themes already exist. Skipping."
fi

# Download icons
if [ ! -d "/usr/share/icons/mint-icons" ]; then
    git clone https://github.com/linuxmint/mint-icons.git /usr/share/icons/mint-icons
    echo "Mint icons installed."
else
    echo "Mint icons already exist. Skipping."
fi

echo "Setting up themes and icons for MATE..."
# Apply Mint themes and icons using MATE settings
gsettings set org.mate.interface gtk-theme "Mint-Y"
gsettings set org.mate.interface icon-theme "Mint-Y"
gsettings set org.mate.Marco.general theme "Mint-Y"

echo "Setting up Plank dock..."
# Add Plank to startup applications and configure it
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/plank.desktop <<EOL
[Desktop Entry]
Type=Application
Exec=plank
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Plank Dock
EOL

# Start Plank for the current session
plank &

echo "Customizing MATE panel for Cinnamon-like appearance..."
# Example: Set panel size to match Cinnamon
gsettings set org.mate.panel.default-layout "classic"
gsettings set org.mate.panel.size 32

echo "Cleaning up..."
apt autoremove -y

echo "All done! Restart your session to see the changes."

