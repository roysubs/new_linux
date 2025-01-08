#!/bin/bash

# Disable GNOME Power Management Settings
# Note: GNOME can enforce sleep or suspend modes, so we disable key settings where applicable.
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' || echo "No such key 'sleep-inactive-ac-type' in GNOME settings"
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' || echo "No such key 'sleep-inactive-battery-type' in GNOME settings"
gsettings set org.gnome.settings-daemon.plugins.power button-lid-suspend 'nothing' || echo "No such key 'button-lid-suspend' in GNOME settings"

# Disable GNOME power settings (to prevent sleep via GNOME)
gsettings set org.gnome.desktop.session idle-delay 0  # Disable screen idle timeout
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false  # Disable screensaver activation

# Disable suspend on lid close (if applicable)
gsettings set org.gnome.settings-daemon.plugins.power button-lid-suspend false

# Disable suspend on power button press
gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'

# Step 6: Check GNOME Logs (Optional)
# If issues persist, review GNOME logs for unexpected power-related events:
# journalctl | grep -i gnome

