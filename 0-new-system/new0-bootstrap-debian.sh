#!/bin/bash
set -e

# Debian Minimal Bootstrap Script for Headless Server
# The bare minimum to get tools and setup Tailscale (optional)
# then backup with Timeshift
# Also will mount all non-boot disks to /mnt/storageX,
# and lays groundwork for Docker/containerized stack.

echo ">>> Updating and installing essentials..."
apt update && apt upgrade -y
apt install -y sudo curl rsync htop vim git unzip net-tools \
  smartmontools lsof ufw fail2ban bash-completion locales

echo ">>> Setting up locale and timezone..."
timedatectl set-timezone UTC
sed -i 's/^# \(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

echo ">>> Setting hostname (optional)..."
read -rp "Enter hostname [default: debian-server]: " HOSTNAME
hostnamectl set-hostname "${HOSTNAME:-debian-server}"

echo ">>> Creating standard container/data dirs..."
mkdir -p /srv/{containers,media,configs,backups}

echo ">>> Preparing to auto-mount non-boot drives under /mnt/storageX..."
BOOT_UUID=$(findmnt -no UUID /)
MOUNT_BASE="/mnt"
i=1

for DEV in /dev/sd?; do
    PART="${DEV}1"
    [[ ! -b "$PART" ]] && continue

    UUID=$(blkid -s UUID -o value "$PART" || true)
    FSTYPE=$(blkid -s TYPE -o value "$PART" || true)

    [[ -z "$UUID" || "$UUID" == "$BOOT_UUID" ]] && continue

    MOUNTPOINT="$MOUNT_BASE/storage$i"
    mkdir -p "$MOUNTPOINT"

    echo ">>> Adding to /etc/fstab: $PART -> $MOUNTPOINT"
    echo "UUID=$UUID  $MOUNTPOINT  $FSTYPE  defaults,noatime  0  2" >> /etc/fstab
    ((i++))
done

echo ">>> Mounting all filesystems..."
mount -a

echo ">>> Enabling and configuring firewall..."
ufw allow OpenSSH
ufw --force enable

echo ">>> Enabling fail2ban..."
systemctl enable --now fail2ban

echo ">>> Optional: Add bash aliases for future container use..."
cat << 'EOF' >> /etc/bash.bashrc

# Docker/container prep aliases (for later use)
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}"'
alias journal='journalctl -xeu'
alias ports='ss -tulnp | grep LISTEN'
EOF

echo ">>> DONE. System is ready for Docker + containers."


