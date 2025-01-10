#!/bin/bash

# This script disables energy-saving features on a Linux system.
# It includes comments and guidance for additional manual steps where appropriate.
echo "Disabling energy-saving features."



# Mask Systemd Targets for Sleep and Suspend
# Disable suspend and hibernation at the system level
# Prevent the system from sleeping via kernel power management
# Masking these targets prevents the system from entering these states.
echo "Disabling suspend and sleep targets in systemd..."
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
# Note: If you need to revert, unmask these targets using the command:
# sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
# Disable hibernation (if using swap partition)
sudo swapoff -a  # Temporarily disable swap hibernation



# Disable suspend on laptop lid close
# Define the path to the logind.conf file
CONFIG_FILE="/etc/systemd/logind.conf"
# Use sed to update the HandleLidSwitch settings
sed -i 's/^#\?HandleLidSwitch=.*/HandleLidSwitch=ignore/' $CONFIG_FILE
sed -i 's/^#\?HandleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=ignore/' $CONFIG_FILE
sed -i 's/^#\?HandleLidSwitchDocked=.*/HandleLidSwitchDocked=ignore/' $CONFIG_FILE
# Restart systemd-logind service
sudo systemctl restart systemd-logind
echo "LidSwitch configuration updated in /etc/systemd/logind.conf and systemd-logind restarted."



# Disable USB Auto-Suspend
# Some devices may not support disabling power control, so errors are expected.
echo "Disabling USB auto-suspend where supported..."
for device in /sys/bus/usb/devices/*; do
    if [ -w "$device/power/control" ]; then
        echo "disabled" | sudo tee "$device/power/control"
    else
        echo "Skipping $device: power control not writable"
    fi
done



# Disable PCI Power Management
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

# Edit sleep.target if further customization is required
# To explicitly override the behavior of the sleep.target:
# 1. Run the following command:
#    sudo systemctl edit sleep.target
# 2. In the editor, add the following lines to disable sleep:
#    [Unit]
#    Description=Sleep Target
#    ConditionPathExists=/nonexistent
# 3. Save and exit.
# This step ensures that sleep.target cannot be activated even if other settings fail.



# Verify the System's Wake Settings
# Sometimes BIOS or firmware settings can enforce sleep modes. Check and disable these if necessary:
# - Access your system's BIOS/UEFI settings.
# - Look for "Power Management" or similar options and disable features like Suspend or Hibernate.



# Final Note:
# After applying these changes, monitor the system to ensure it no longer enters unintended sleep or suspend modes.
echo "Energy-saving features have been disabled. Monitor the system to confirm changes."

