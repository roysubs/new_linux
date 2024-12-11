#!/bin/bash
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin

# Check if running as sudo
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run with sudo or as root."
  exit 1
fi

# Check if timeshift is installed
if ! command -v timeshift &> /dev/null; then
  echo "Installing Timeshift..."
  sudo apt update && apt install -y timeshift
  if ! command -v timeshift &> /dev/null; then
    echo "Timeshift failed to install. Exiting."
    exit 1
  fi
fi

# Offer to run the first snapshot creation
echo "Timeshift is now installed and set to rsync mode."
read -p "Do you want to create the first snapshot now? (y/n): " answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
  # Run first snapshot creation
  echo "Creating the first snapshot..."
  timeshift --create --rsync
  echo "First snapshot created."
else
  echo "First snapshot creation skipped."
fi

