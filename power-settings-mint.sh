#!/bin/bash

# To stop Linux Mint suspending on laptop lid close

# Define the path to the logind.conf file
CONFIG_FILE="/etc/systemd/logind.conf"

# Use sed to update the HandleLidSwitch settings
sed -i 's/^#\?HandleLidSwitch=.*/HandleLidSwitch=ignore/' $CONFIG_FILE
sed -i 's/^#\?HandleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=ignore/' $CONFIG_FILE
sed -i 's/^#\?HandleLidSwitchDocked=.*/HandleLidSwitchDocked=ignore/' $CONFIG_FILE

# Restart systemd-logind service
sudo systemctl restart systemd-logind

echo "LidSwitch configuration updated in /etc/systemd/logind.conf and systemd-logind restarted."

