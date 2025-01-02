#!/bin/bash

# Install and enable OpenSSH for remote access.

# First line checks running as root or with sudo (exit 1 if not). Second line auto-elevates the script as sudo.
# if [ "$(id -u)" -ne 0 ]; then echo "This script must be run as root or with sudo" 1>&2; exit 1; fi
if [ "$(id -u)" -ne 0 ]; then echo "Elevation required; rerunning with sudo..."; sudo "$0" "$@"; exit 0; fi

# Only update if it's been more than 2 days since the last update (to avoid constant updates)
if [ $(find /var/cache/apt/pkgcache.bin -mtime +2 -print) ]; then sudo apt update && sudo apt upgrade; fi

# Install tools if not already installed
PACKAGES=("openssh-server")
install-if-missing() { if ! dpkg-query -W "$1" > /dev/null 2>&1; then sudo apt install -y $1; fi; }
for package in "${PACKAGES[@]}"; do install-if-missing $package; done

# Ensure that OpenSSH is enabled and started
echo "Setting up OpenSSH server..."
sudo systemctl enable ssh
sudo systemctl start ssh

# Output summary with user and IPv4 address, use command substitution to get sudo user or root
user=$( if [ -n "$SUDO_USER" ]; then echo "$SUDO_USER"; else whoami; fi )
ip=$(hostname -I | awk '{print $1}')
echo "OpenSSH is now set up on this server."
echo "Access this server with 'ssh $user@$ip'."
