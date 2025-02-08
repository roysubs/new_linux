#!/bin/bash

# Function to display and execute commands
run_command() {
    echo -e "\033[1;33mRunning: $1\033[0m"
    eval "$1"
}

# Update and upgrade system packages
run_command "sudo apt update && sudo apt upgrade -y"

# Install common utilities
run_command "sudo apt install -y curl wget git htop neofetch vim nano tree zip unzip"

# Set up a better .bashrc
run_command "cp ~/.bashrc ~/.bashrc.backup"
run_command "echo 'alias ll="ls -alF"' >> ~/.bashrc"
run_command "echo 'export EDITOR=nano' >> ~/.bashrc"
run_command "source ~/.bashrc"

# Fix time synchronization
run_command "sudo apt install -y ntp"
run_command "sudo systemctl enable ntp --now"

# Enable firewall and allow SSH
run_command "sudo ufw allow OpenSSH"
run_command "sudo ufw enable"

# Set correct permissions for home directory
run_command "chmod 700 ~"

# Remove orphaned packages
run_command "sudo apt autoremove -y"

# Clean package cache
run_command "sudo apt autoclean -y"

# Enable color in grep
run_command "echo 'export GREP_OPTIONS="--color=auto"' >> ~/.bashrc"

# Set hostname properly
run_command "sudo hostnamectl set-hostname my-linux-machine"

# Optimize swappiness
run_command "echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf"
run_command "sudo sysctl -p"

# Enable TRIM for SSDs
run_command "sudo systemctl enable fstrim.timer --now"

# Add useful aliases
run_command "echo 'alias cls="clear"' >> ~/.bashrc"
run_command "echo 'alias update="sudo apt update && sudo apt upgrade -y"' >> ~/.bashrc"

# Install fail2ban for security
run_command "sudo apt install -y fail2ban"
run_command "sudo systemctl enable fail2ban --now"

# Optimize system performance
run_command "echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf"
run_command "sudo sysctl -p"

# Set up automatic updates
run_command "sudo apt install -y unattended-upgrades"
run_command "sudo dpkg-reconfigure --priority=low unattended-upgrades"

# Check for broken packages
run_command "sudo dpkg --configure -a"
run_command "sudo apt install -f"

# Clean journal logs over 1G
run_command "sudo journalctl --vacuum-size=1G"

# Remove old kernels (except the current one)
run_command "sudo apt-get autoremove --purge"

# Install preload to speed up app launch
run_command "sudo apt install -y preload"

# Set up bash completion
run_command "sudo apt install -y bash-completion"
run_command "echo 'if [ -f /etc/bash_completion ]; then . /etc/bash_completion; fi' >> ~/.bashrc"

# Optimize DNS resolution
run_command "sudo systemctl enable systemd-resolved --now"

# Enable zswap for performance
run_command "echo 'zswap.enabled=1' | sudo tee -a /etc/default/grub"
run_command "sudo update-grub"

# Install and enable AppArmor for security
run_command "sudo apt install -y apparmor apparmor-profiles"
run_command "sudo systemctl enable apparmor --now"

# Enable auditd for logging security events
run_command "sudo apt install -y auditd"
run_command "sudo systemctl enable auditd --now"

# Install ClamAV for antivirus scanning
run_command "sudo apt install -y clamav clamav-daemon"
run_command "sudo systemctl enable clamav-daemon --now"

# Secure shared memory
run_command "echo 'tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' | sudo tee -a /etc/fstab"
run_command "sudo mount -o remount /run/shm"

# Harden SSH configuration
run_command "sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config"
run_command "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config"
run_command "sudo systemctl restart sshd"

# Install firejail for sandboxing
run_command "sudo apt install -y firejail"

# Disable IPv6 if not needed
run_command "echo 'net.ipv6.conf.all.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf"
run_command "sudo sysctl -p"

# Install and enable OpenSSH server
run_command "sudo apt install -y openssh-server"
run_command "sudo systemctl enable ssh --now"

# Configure automatic time synchronization
run_command "sudo timedatectl set-ntp on"

# More fixes and optimizations can be added... this is a more comprehensive setup!

echo -e "\033[1;32mSystem tweaks complete!\033[0m"

