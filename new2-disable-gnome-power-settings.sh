#!/bin/bash

# This script disables energy-saving features on a Linux system, particularly for GNOME and hardware settings.
# It includes comments and guidance for additional manual steps where appropriate.

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

# Step 1: Disable GNOME Power Management Settings
# Note: GNOME can enforce sleep or suspend modes, so we disable key settings where applicable.
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' || echo "No such key 'sleep-inactive-ac-type' in GNOME settings"
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' || echo "No such key 'sleep-inactive-battery-type' in GNOME settings"
gsettings set org.gnome.settings-daemon.plugins.power button-lid-suspend 'nothing' || echo "No such key 'button-lid-suspend' in GNOME settings"

# Step 2: Mask Systemd Targets for Sleep and Suspend
# Masking these targets prevents the system from entering these states.
echo "Disabling suspend and sleep targets in systemd..."
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Note: If you need to revert, unmask these targets using the command:
# sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Step 3: Disable USB Auto-Suspend
# Some devices may not support disabling power control, so errors are expected.
echo "Disabling USB auto-suspend where supported..."
for device in /sys/bus/usb/devices/*; do
    if [ -w "$device/power/control" ]; then
        echo "disabled" | sudo tee "$device/power/control"
    else
        echo "Skipping $device: power control not writable"
    fi
done

# Step 4: Disable PCI Power Management
# Ensures PCI devices don't enter power-saving modes.
echo "Disabling PCI power-saving features..."
for device in /sys/bus/pci/devices/*; do
    if [ -w "$device/power/control" ]; then
        echo "on" | sudo tee "$device/power/control"
    else
        echo "Skipping $device: power control not writable"
    fi
done

# Additional Manual Steps

# Step 5: Edit sleep.target if further customization is required
# To explicitly override the behavior of the sleep.target:
# 1. Run the following command:
#    sudo systemctl edit sleep.target
# 2. In the editor, add the following lines to disable sleep:
#    [Unit]
#    Description=Sleep Target
#    ConditionPathExists=/nonexistent
# 3. Save and exit.
# This step ensures that sleep.target cannot be activated even if other settings fail.

# Step 6: Check GNOME Logs (Optional)
# If issues persist, review GNOME logs for unexpected power-related events:
# journalctl | grep -i gnome

# Step 7: Verify the System's Wake Settings
# Sometimes BIOS or firmware settings can enforce sleep modes. Check and disable these if necessary:
# - Access your system's BIOS/UEFI settings.
# - Look for "Power Management" or similar options and disable features like Suspend or Hibernate.

# Final Note:
# After applying these changes, monitor the system to ensure it no longer enters unintended sleep or suspend modes.
echo "Energy-saving features have been disabled. Monitor the system to confirm changes."

