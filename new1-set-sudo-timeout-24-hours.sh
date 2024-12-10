#!/bin/bash

# Ensure we're running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root!" 1>&2
  exit 1
fi

# Define the line to be added
SUDOERS_LINE="Defaults        timestamp_timeout=1440"

# Check if the line already exists in the sudoers file
if grep -q "^Defaults.*timestamp_timeout" /etc/sudoers; then
  echo "timestamp_timeout is already set in /etc/sudoers."
  echo "To manually alter the value, run:    sudo visudo"
else
  # Safely add the line to the sudoers file using visudo
  echo "Adding timestamp_timeout setting to /etc/sudoers..."
  echo "$SUDOERS_LINE" | EDITOR='tee -a' visudo > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "Successfully updated /etc/sudoers with timestamp_timeout=1440."
  else
    echo "Failed to update /etc/sudoers. Please check for errors."
    exit 1
  fi
fi

