#!/bin/bash

# Ensure script exits immediately if a command exits with a non-zero status.
# Exceptions are made for specific commands where failure is expected or handled (like the ssh-add check below).
set -e

# Color function for green text
green() { echo -e "\033[1;32m$*\033[0m"; }
red() { echo -e "\033[1;31m$*\033[0m"; } # Added red for warnings/errors

run_cmd() {
    green "\$ $*"
    # Use eval to correctly handle commands with quotes or variables like the ssh-agent eval
    eval "$@"
}

pause_msg() {
    echo -e "\n\033[1;33m$1\033[0m"
    # Use /dev/tty for read to ensure it reads from the terminal even if stdin is redirected
    read -rp "Press Enter to continue..." </dev/tty
}

green "=== GitHub SSH Setup Script ==="

# Step 1: Check if Git is installed
green "\nStep 1: Checking for Git installation..."
if ! command -v git &>/dev/null; then
    red "Error: Git not found. Please install Git before proceeding."
    exit 1
fi
run_cmd "git --version"

# Step 2: Check existing SSH keys
green "\nStep 2: Checking for existing SSH keys..."
ls -l ~/.ssh/id_*.pub 2>/dev/null || echo "No SSH public keys found."

# Step 3: Generate SSH key if missing
green "\nStep 3: Checking/Generating SSH key..."
if [ ! -f ~/.ssh/id_ed25519 ]; then
    green "No ed25519 key found. Generating one..."
    GIT_EMAIL=$(git config --global user.email)
    if [ -z "$GIT_EMAIL" ]; then
        red "Error: Git email not set globally."
        echo "Please configure with: git config --global user.email \"your@email.com\""
        exit 1
    fi
    run_cmd "ssh-keygen -t ed25519 -C \"$GIT_EMAIL\""
else
    echo "SSH key already exists at ~/.ssh/id_ed25519"
fi

# Step 4: Start ssh-agent and add key
green "\nStep 4: Starting ssh-agent and adding key..."
# Note: eval "$(ssh-agent -s)" needs to be run directly in your shell
# or sourced from a script for its environment variables to persist.
# Running it via a script like this will start an agent, but the ENV
# vars might only be set within the script's subprocess.
# However, for the subsequent `ssh-add` and `ssh -T` within this same script
# execution, the environment should be inherited correctly.
run_cmd 'eval "$(ssh-agent -s)"'
# Use || true here to prevent set -e from exiting if the key was already added
# (ssh-add exits with 1 if the key is already present) or if the agent wasn't started correctly.
run_cmd 'ssh-add ~/.ssh/id_ed25519 || true'

# Step 5: Verify SSH agent is running and key is added
green "\nStep 5: Verifying SSH agent and key..."
# Check if ssh-add -l runs successfully (agent is accessible)
# and if its output contains the expected key name.
# We redirect stderr to /dev/null for the check itself to avoid "Could not open connection" messages cluttering output
# when the agent is indeed not running.
if ssh-add -l 2>/dev/null | grep -q id_ed25519; then
    green "SSH agent is running and key 'id_ed25519' is loaded successfully."
else
    # Use || true here to prevent set -e from exiting just because this check fails
    ssh-add -l || true # Run ssh-add -l again without suppressing output so the user can see the error message if any
    red "\nWarning: Could not verify SSH agent is running or key 'id_ed25519' is loaded."
    echo "This means subsequent SSH operations (like push/pull) might fail."
    echo "Ensure 'eval \"\$(ssh-agent -s)\"' was run and your key was added manually if needed."
fi


# Step 6: Show public key for GitHub
green "\nStep 6: Displaying your SSH public key:"
if [ -f ~/.ssh/id_ed25519.pub ]; then
    cat ~/.ssh/id_ed25519.pub
else
    red "Error: SSH public key file not found at ~/.ssh/id_ed25519.pub"
    # We don't exit here, maybe the user just needs the other steps.
fi


pause_msg "📋 Copy the key displayed above, then go to https://github.com → Settings → SSH and GPG keys → New SSH key, and paste it there."

# Step 7: Test SSH connection
green "\nStep 7: Testing SSH connection to GitHub..."
# Use || true because ssh -T is expected to exit with 1 if successful authentication happens but no PTY is allocated (which is normal).
# It will exit with a different code on authentication failure or other errors.
# We just want to see the output and not stop the script if the exit code is 1.
run_cmd "ssh -T git@github.com || true"

# Step 8: Check or update Git remote
green "\nStep 8: Checking/Updating Git remote URL..."

# Check if we are in a git repository first
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    red "Warning: Not currently in a Git repository."
    echo "Skipping remote URL check/update."
else
    cd "$(git rev-parse --show-toplevel)" || exit 1 # Move to repo root

    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")

    if [[ "$REMOTE_URL" == https://github.com/* ]]; then
        green "Updating remote URL to use SSH instead of HTTPS:"
        # Check if the URL is a valid HTTPS GitHub URL before attempting transformation
        if [[ "$REMOTE_URL" =~ ^https://github\.com/[^/]+/[^/]+\.git$ ]]; then
            SSH_URL="${REMOTE_URL/https:\/\/github.com\//git@github.com:}"
            run_cmd "git remote set-url origin $SSH_URL"
        else
             red "Warning: Origin remote URL is HTTPS but not in expected github.com/user/repo.git format."
             echo "Current URL: $REMOTE_URL"
             echo "Skipping automatic update. Please update manually if needed."
        fi
    else
        echo "Git remote 'origin' already using SSH or not set:"
        run_cmd "git remote -v"
    fi
fi


# Step 9: Final reminder
green "\nStep 9: You’re now ready to push! 🎉"
echo "To commit changes and push, run the following commands:"
green "git add ."
green "git commit -m \"your message\""
green "git push"
