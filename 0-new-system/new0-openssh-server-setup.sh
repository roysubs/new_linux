#!/bin/bash

# Install and enable OpenSSH for remote access.
# Supports both native Linux and WSL (Windows Subsystem for Linux)

# Auto-elevate with sudo if not root
if [ "$(id -u)" -ne 0 ]; then
  echo "Elevation required; rerunning with sudo..."
  sudo "$0" "$@"
  exit 0
fi

# Detect if running in WSL
is_wsl() {
  grep -qiE 'microsoft|wsl' /proc/version
}

# Only update if apt cache is older than 2 days
if [ -f /var/cache/apt/pkgcache.bin ] && find /var/cache/apt/pkgcache.bin -mtime +2 | grep -q .; then
  apt update && apt upgrade -y
fi

# Ensure ssh server package is installed
apt install -y openssh-server openssh-client

echo "Setting up OpenSSH server..."

if is_wsl; then
  echo "🟡 Detected WSL — systemd is not available. Skipping systemctl-based startup."
  echo "ℹ️  Running sshd manually (note: this is not persistent across reboots)."
  
  # WSL-specific fix: disable PAM if present
  if grep -q '^UsePAM yes' /etc/ssh/sshd_config; then
    sed -i 's/^UsePAM yes/UsePAM no/' /etc/ssh/sshd_config
    echo "✅ Disabled PAM in sshd_config (WSL doesn't support it)."
  fi

  mkdir -p /var/run/sshd
  /usr/sbin/sshd

  echo "✅ sshd is now running manually."
  echo "⚠️  If you restart WSL, you'll need to run: sudo /usr/sbin/sshd"
else
  # Native Linux — use systemctl
  systemctl enable ssh
  systemctl start ssh
  echo "✅ ssh.service started via systemd."
fi

# Summary
user=$( [ -n "$SUDO_USER" ] && echo "$SUDO_USER" || whoami )
ip=$(hostname -I | awk '{print $1}')
echo
echo "🔐 OpenSSH is now set up."
echo "➡️  Access this system with: ssh $user@$ip"

