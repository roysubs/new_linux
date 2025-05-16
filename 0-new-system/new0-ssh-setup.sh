#!/bin/bash

set -e

GREEN="\033[1;32m"
RESET="\033[0m"

function run_step() {
  echo -e "${GREEN}$1${RESET}"
  eval "$1"
}

function prompt_install() {
  read -p "OpenSSH server is not installed. Install it now? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    if command -v apt >/dev/null 2>&1; then
      run_step "sudo apt update"
      run_step "sudo apt install -y openssh-server"
    elif command -v dnf >/dev/null 2>&1; then
      run_step "sudo dnf install -y openssh-server"
    elif command -v yum >/dev/null 2>&1; then
      run_step "sudo yum install -y openssh-server"
    elif command -v pacman >/dev/null 2>&1; then
      run_step "sudo pacman -Sy --noconfirm openssh"
    else
      echo "Unsupported package manager. Please install openssh-server manually."
      exit 1
    fi
  else
    echo "Aborting: OpenSSH not installed."
    exit 1
  fi
}

echo "🔍 Checking if sshd is installed..."
if ! command -v sshd >/dev/null 2>&1; then
  prompt_install
else
  echo "✅ OpenSSH server is already installed."
fi

echo "🔧 Ensuring ssh service is enabled and started..."
SERVICE_NAME="ssh"
if systemctl list-units --type=service | grep -q sshd.service; then
  SERVICE_NAME="sshd"
fi

run_step "sudo systemctl enable $SERVICE_NAME"
run_step "sudo systemctl start $SERVICE_NAME"
run_step "sudo systemctl status $SERVICE_NAME --no-pager --lines=5"

echo "🔍 Verifying sshd_config settings..."
CONFIG="/etc/ssh/sshd_config"

[[ -f "$CONFIG" ]] || { echo "❌ sshd_config not found at $CONFIG"; exit 1; }

PORT_SET=$(grep -Ei '^Port ' "$CONFIG" || echo "Port not explicitly set")
echo "Port line in config: $PORT_SET"

echo "🔍 Checking if port 22 is listening..."
if sudo ss -tuln | grep -q ':22 '; then
  echo "✅ Port 22 is open and listening."
else
  echo "❌ Port 22 is not open! SSH might not be accepting connections."
  echo "Try: sudo systemctl restart $SERVICE_NAME"
fi

echo "🔍 Testing connectivity with netcat..."
if command -v nc >/dev/null 2>&1; then
  run_step "nc -zv 127.0.0.1 22 || echo '⚠️  Port 22 not reachable via nc'"
else
  echo "⚠️  netcat (nc) not found. Skipping connectivity test."
fi

echo ""
echo "📋 FINAL NOTES:"
echo ""
echo "💡 UFW (Ubuntu/Debian):"
echo "   sudo ufw allow ssh"
echo "   sudo ufw status"
echo ""
echo "💡 firewalld (Fedora/CentOS/RHEL):"
echo "   sudo firewall-cmd --permanent --add-service=ssh"
echo "   sudo firewall-cmd --reload"
echo ""
echo "💡 iptables:"
echo "   sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT"
echo ""
echo "✅ SSH setup check complete."

