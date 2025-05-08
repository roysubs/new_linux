#!/bin/bash

set -e

# Color function for green text
green() { echo -e "\033[1;32m$*\033[0m"; }

run_cmd() {
    green "\$ $*"
    eval "$@"
}

pause_msg() {
    echo -e "\n\033[1;33m$1\033[0m"
    read -rp "Press Enter to continue..."
}

green "=== GitHub SSH Setup Script ==="

# Step 1: Check if Git is installed
if ! command -v git &>/dev/null; then
    echo "Git not found. Please install Git before proceeding."
    exit 1
fi
run_cmd "git --version"

# Step 2: Check existing SSH keys
green "\nChecking for existing SSH keys:"
ls -l ~/.ssh/id_*.pub || echo "No SSH public keys found."

# Step 3: Generate SSH key if missing
if [ ! -f ~/.ssh/id_ed25519 ]; then
    green "\nNo ed25519 key found. Generating one..."
    GIT_EMAIL=$(git config --global user.email)
    if [ -z "$GIT_EMAIL" ]; then
        echo "Git email not set. Please configure with: git config --global user.email \"your@email.com\""
        exit 1
    fi
    run_cmd "ssh-keygen -t ed25519 -C \"$GIT_EMAIL\""
else
    echo "SSH key already exists at ~/.ssh/id_ed25519"
fi

# Step 4: Start ssh-agent and add key
run_cmd 'eval "$(ssh-agent -s)"'
run_cmd 'ssh-add ~/.ssh/id_ed25519'

# Step 5: Show public key for GitHub
green "\nHere is your SSH public key:\n"
cat ~/.ssh/id_ed25519.pub

pause_msg "📋 Copy the key above, then go to https://github.com → Settings → SSH and GPG keys → New SSH key, and paste it there."

# Step 6: Test SSH connection
green "\nTesting SSH connection to GitHub..."
run_cmd "ssh -T git@github.com || true"

# Step 7: Check or update Git remote
cd "$(git rev-parse --show-toplevel)" || exit 1

REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")

if [[ "$REMOTE_URL" == https://github.com/* ]]; then
    green "\nUpdating remote URL to use SSH instead of HTTPS:"
    SSH_URL="${REMOTE_URL/https:\/\/github.com\//git@github.com:}"
    run_cmd "git remote set-url origin $SSH_URL"
else
    echo -e "\nGit remote already using SSH or not set:"
    run_cmd "git remote -v"
fi

# Step 8: Try a push (dry run)
green "\nYou’re now ready to push!"
echo "Run the following to push changes:"
green "git add . && git commit -m \"your message\" && git push"

pause_msg "🎉 Done! Press Enter to exit."

