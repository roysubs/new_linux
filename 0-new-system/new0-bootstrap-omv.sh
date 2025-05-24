#!/bin/bash

# omv-new-start.sh — First-time setup script for OpenMediaVault + Server enhancements
# This script is idempotent and safe to re-run. It configures useful server tools, highlights OMV quirks,
# and reminds the user of what OMV manages vs. what is fair game.

set -euo pipefail

# -----------------------------
# 🔧 Functions
# -----------------------------

color() { echo -e "\e[1;36m$1\e[0m"; }
warn()  { echo -e "\e[1;33m$1\e[0m"; }
info()  { echo -e "\e[1;32m$1\e[0m"; }

install_if_missing() {
  if ! dpkg -s "$1" &>/dev/null; then
    info "Installing $1..."
    apt-get install -y "$1"
  else
    info "$1 is already installed."
  fi
}

setup_tailscale() {
  if ! command -v tailscale &>/dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
    info "Tailscale installed. Now run 'tailscale up' to connect."
  else
    info "Tailscale is already installed."
  fi
}

setup_timeshift() {
  if ! command -v timeshift &>/dev/null; then
    add-apt-repository -y ppa:teejee2008/ppa
    apt update
    apt install -y timeshift
  else
    info "Timeshift is already installed."
  fi
}

prompt_timeshift_backup() {
  read -rp $'\nWould you like to create a Timeshift backup now? [y/N]: ' reply
  if [[ $reply =~ ^[Yy]$ ]]; then
    sudo timeshift --create --comments "Initial OMV Setup"
  else
    info "Skipping Timeshift snapshot."
  fi
}

install_portainer_plugin() {
  if omv-confdbadm read "conf.system.omvextras" | grep -q 'portainer'; then
    info "Portainer plugin already installed via OMV extras."
  else
    read -rp $'\nWould you like to install the official Portainer plugin via OMV Extras? [y/N]: ' reply
    if [[ $reply =~ ^[Yy]$ ]]; then
      omv-confdbadm populate
      omv-confdbadm create "conf.system.omvextras.portainer"
      omv-salt deploy run omvextras
      info "Portainer plugin installed."
    else
      info "Skipped Portainer plugin installation."
    fi
  fi
}

install_sharerootfs_plugin() {
  if omv-confdbadm read "conf.system.omvextras" | grep -q 'sharerootfs'; then
    info "Sharerootfs plugin already installed via OMV extras."
  else
    read -rp $'\nWould you like to install the OMV sharerootfs plugin via OMV Extras? [y/N]: ' reply
    if [[ $reply =~ ^[Yy]$ ]]; then
      omv-confdbadm populate
      omv-confdbadm create "conf.system.omvextras.sharerootfs"
      omv-salt deploy run omvextras
      info "Sharerootfs plugin installed."
      # sudo apt install openmediavault-sharerootfs
    else
      info "Skipped sharerootfs plugin installation."
    fi
  fi
}

setup_home_folders() {
  if ! grep -q 'OMV_CREATE_HOME' /etc/default/openmediavault; then
    echo 'OMV_CREATE_HOME="yes"' >> /etc/default/openmediavault
    omv-salt stage run prepare && omv-salt deploy run user
    info "Enabled automatic home folder creation for new users."
  else
    info "User home folder creation already enabled."
  fi
}


print_summary() {
  color "\n========= ✅ OMV SETUP SUMMARY ========="
  echo "
- You CAN and SHOULD run: \e[1mapt update && apt upgrade\e[0m"
  echo "- Avoid: \e[1mapt full-upgrade\e[0m unless you know what you're doing"
  echo "- Never run: \e[1mdo-release-upgrade\e[0m — will break OMV"

  echo "
- OMV manages:
  • Users (via GUI)
  • Shared folders and permissions
  • Network settings
  • Services (SMB/NFS/etc.)
  • Docker (optionally via Portainer plugin)

- You can safely manage:
  • CLI utilities, apt installs
  • Custom scripts and tools
  • Home folder settings (if enabled)
  • Tailscale, Timeshift, and other userland tools

- OMV disables some system services, like NTP or systemd-timesyncd. You may see warnings like:
    Failed to stop ntp.service: Unit ntp.service not loaded.
    Created symlink /etc/systemd/system/ntp.service → /dev/null.
  These are safe to ignore and caused by OMV intentionally masking them.

- WARNING: OMV does NOT allow user home directories under /home.
  • It insists on placing them inside a Shared Folder on a separate mounted volume.
  • You CANNOT set the home dir until you mount a drive and create a shared folder.
  • This behavior is hardcoded and non-configurable via GUI.
  • If you need standard /home/username paths, OMV may not be the right tool.
  "
}

# -----------------------------
# 🚀 Script Entry Point
# -----------------------------

color "\n========= 🛠 Starting OMV Initial Setup Script ========="

info "Updating APT cache..."
apt update

install_if_missing sudo
install_if_missing curl
install_if_missing gnupg
install_if_missing software-properties-common
install_if_missing lsb-release

install_portainer_plugin
install_sharerootfs_plugin

setup_home_folders
setup_tailscale
setup_timeshift

print_summary
prompt_timeshift_backup

color "\n========= ✅ OMV SETUP COMPLETE ========="

