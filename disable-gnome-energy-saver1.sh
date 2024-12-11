#!/bin/bash

# Disable GNOME power settings (to prevent sleep via GNOME)
gsettings set org.gnome.desktop.session idle-delay 0  # Disable screen idle timeout
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false  # Disable screensaver activation

# Disable suspend on lid close (if applicable)
gsettings set org.gnome.settings-daemon.plugins.power button-lid-suspend false

# Disable suspend on power button press
gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'

# Disable suspend and hibernation at the system level
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Disable hibernation (if using swap partition)
sudo swapoff -a  # Temporarily disable swap hibernation

# Prevent the system from sleeping via kernel power management
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Ensure all power-saving features are disabled
echo "Energy-saving features disabled."

