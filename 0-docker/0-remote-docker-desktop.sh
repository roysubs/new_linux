#!/bin/bash

set -e

echo "⚠️  This script should be run on the system running Docker Desktop that you want to use to manage a remote Docker server."
read -rp "Continue? [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "❌ Aborted."; exit 1; }

# Prompt for remote user and host
read -rp "👤 Enter the SSH username for the remote Docker host: " REMOTE_USER
read -rp "🌐 Enter the IP or hostname of the remote Docker host: " REMOTE_HOST

# SSH key path
SSH_KEY="$HOME/.ssh/id_rsa"

echo "🔐 Checking for existing SSH key at $SSH_KEY..."
if [[ ! -f "$SSH_KEY" ]]; then
  echo "🧾 No SSH key found, generating one..."
  ssh-keygen -t rsa -b 4096 -N "" -f "$SSH_KEY"
else
  echo "✅ SSH key already exists."
fi

echo "📤 Copying SSH public key to ${REMOTE_USER}@${REMOTE_HOST}..."
ssh-copy-id "${REMOTE_USER}@${REMOTE_HOST}"

echo "🔁 Verifying passwordless SSH access..."
if ssh -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" true; then
  echo "✅ SSH login works without password."
else
  echo "❌ SSH login failed. Please debug manually."
  exit 1
fi

# Docker context name
CONTEXT_NAME="remote_${REMOTE_HOST//./_}"

echo "🧼 Checking for DOCKER_HOST override in ~/.bashrc..."
if grep -q "DOCKER_HOST" ~/.bashrc; then
  echo "📦 Found DOCKER_HOST in .bashrc, backing up and removing..."
  cp ~/.bashrc ~/.bashrc.bak.$(date +%s)
  sed -i '/DOCKER_HOST/d' ~/.bashrc
  echo "🧽 Cleaned up DOCKER_HOST export line."
fi

echo "🔧 Creating Docker context '$CONTEXT_NAME'..."
docker context create "$CONTEXT_NAME" \
  --docker "host=ssh://${REMOTE_USER}@${REMOTE_HOST}"

echo "🎯 Switching to Docker context '$CONTEXT_NAME'..."
docker context use "$CONTEXT_NAME"

echo "🔍 Fetching remote Docker info..."
docker info | grep -E 'Name|Operating System|Kernel'

echo "✅ Setup complete. Docker CLI now targets $REMOTE_HOST via context '$CONTEXT_NAME'."

