#!/bin/bash

# connect a git project to github securely with ssh.
# and switch the project to ssh if it was cloned via https.
# (ssh is easier and more widely used than https).

# set -e ensures that the script exits immediately if a command exits with a non-zero status.
# Exceptions are made for specific commands where failure is expected or handled (like the ssh-add check below).
set -e

# Color functions
red()    { echo -e "\033[1;31m$*\033[0m"; }
green()  { echo -e "\033[1;32m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }

# Function to run commands and show them
run_cmd() {
    green "\$ $*"
    # Use eval to correctly handle commands with quotes or variables like the ssh-agent eval
    eval "$@"
}

# Function to pause with a message
pause_msg() {
    echo -e "\n\033[1;33m$1\033[0m"
    # Use /dev/tty for read to ensure it reads from the terminal even if stdin is redirected
    read -rp "Press Enter to continue..." </dev/tty
}

echo
yellow "=== GitHub SSH Setup Script ==="
echo "Connect a git project to github securely with SSH and"
echo "cloned via https (SSH is generally easier and more widely used than HTTPS)."
echo "Generate SSH keys if required:  ssh-keygen -t ed25519 -C <email>;  cat ~/.ssh/id_ed25519.pub"
echo "Start SSH agent:  eval \"$(ssh-agent -s)\""
echo "Test SSH connection to GitHub:  ssh -T git@github.com"
echo "Check if the project was cloned using HTTPS and if so, wwitch to SSH with:"
echo "  git remote set-url origin git@github.com:<user>/<repo>.git"

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
green "\nStep 3: Checking/Generatign SSH key..."
if [ ! -f ~/.ssh/id_ed25519 ]; then
    green "No ed25519 key found. Generating one..."
    GIT_EMAIL=$(git config --global user.email)
    if [ -z "$GIT_EMAIL" ]; then
        red "Error: Git email not set globally."
        echo "Please configure with: git config --global user.email \"your@email.com\""
        exit 1
    fi
    # Use run_cmd to show the command, but pipe output/errors for ssh-keygen interactiveness
    green "\$ ssh-keygen -t ed25519 -C \"$GIT_EMAIL\""
    ssh-keygen -t ed25519 -C "$GIT_EMAIL"
    # Check if key generation was successful
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        red "Error: SSH key generation failed."
        exit 1
    fi
else
    echo "SSH key already exists at ~/.ssh/id_ed25519"
fi

# Step 4: Start ssh-agent and add key
green "\nStep 4: Starting ssh-agent and adding key..."
# Note: eval "$(ssh-agent -s)" needs to be run directly in your shell
# or sourced from a script for its environment variables to persist beyond this script.
# However, for the subsequent `ssh-add` and `ssh -T` *within this same script execution*,
# the environment should be inherited correctly.
run_cmd 'eval "$(ssh-agent -s)"'
# Use || true here to prevent set -e from exiting if the key was already added
# (ssh-add exits with 1 if the key is already present) or if the agent wasn't started correctly.
run_cmd 'ssh-add ~/.ssh/id_ed25519 || true'

# Step 5: Verify SSH agent is running and key is added
green "\nStep 5: Verifying SSH agent and key..."
# Check if ssh-add -l runs successfully (agent is accessible)
# and if its output contains the expected key type (ED25519).
# We redirect stderr to /dev/null for the check itself to avoid "Could not open connection"
# messages cluttering output when the agent is indeed not running or key not loaded correctly.
if ssh-add -l 2>/dev/null | grep -q ED25519; then
    green "SSH agent is running and key 'id_ed25519' (ED25519) is loaded successfully."
else
    # Run ssh-add -l again without suppressing output so the user can see the error message if any
    # Use || true to prevent exiting due to set -e if ssh-add -l fails
    ssh-add -l || true
    red "\nWarning: Could not verify SSH agent is running or key 'id_ed25519' is loaded."
    echo "This means subsequent SSH operations (like push/pull) might fail."
    echo "Ensure 'eval \"\$(ssh-agent -s)\"' was run in your current shell and your key was added manually if needed."
fi


# Step 6: Show public key for GitHub
green "\nStep 6: Displaying your SSH public key:"
if [ -f ~/.ssh/id_ed25519.pub ]; then
    cat ~/.ssh/id_ed25519.pub
else
    red "Error: SSH public key file not found at ~/.ssh/id_ed25519.pub"
    # We don't exit here, maybe the user just needs the other steps.
fi

pause_msg "📋 Copy the key displayed above, then go to:\nhttps://github.com → Settings → SSH and GPG keys → New SSH key.\nPaste the key there and save it before continuing."

# Step 7: Test SSH connection
green "\nStep 7: Testing SSH connection to GitHub..."
# Use || true because ssh -T is expected to exit with 1 if successful authentication happens but no PTY is allocated (which is normal).
# It will exit with a different code on authentication failure or other errors.
# We just want to see the output and not stop the script if the exit code is 1.
run_cmd "ssh -T git@github.com || true"

# Step 8: Check or update Git remote (Automatic HTTPS to SSH conversion)
green "\nStep 8: Checking Git remote URL..."

# Check if we are in a git repository first
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    red "Warning: Not currently in a Git repository."
    echo "Skipping remote URL check/update."
else
    # Move to the repository root directory
    cd "$(git rev-parse --show-toplevel)" || { red "Error: Could not navigate to repository root."; exit 1; }

    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")

    if [ -z "$REMOTE_URL" ]; then
        yellow "No 'origin' remote URL found in this repository."
        echo "Add a remote URL using: git remote add origin <url>"
    # Use a less strict regex to match HTTPS GitHub URLs, capturing user and repo
    elif [[ "$REMOTE_URL" =~ ^https://github\.com/([^/]+)/([^/]+) ]]; then
        # Extract user and repo from regex capture groups
        GIT_USER=${BASH_REMATCH[1]}
        GIT_REPO=${BASH_REMATCH[2]}

        # Construct the SSH URL explicitly, always adding the .git suffix
        SSH_URL="git@github.com:${GIT_USER}/${GIT_REPO}.git"

        green "Origin remote URL is currently HTTPS: $REMOTE_URL"
        echo "Attempting to update 'origin' remote URL to SSH: $SSH_URL"

        # Run the command directly to capture exit status for specific feedback
        git remote set-url origin "$SSH_URL"
        EXIT_STATUS=$? # Capture the exit status of the previous command

        if [ $EXIT_STATUS -eq 0 ]; then
            green "✅ Successfully updated 'origin' remote URL to SSH."
            run_cmd "git remote -v" # Show the updated URL using run_cmd for consistent output style
        else
            red "❌ Error: Failed to set 'origin' remote URL to SSH."
            echo "Please check the URL format or update manually."
        fi
    # Add an explicit check for the SSH format so it doesn't fall into the "different protocol/host" message
    elif [[ "$REMOTE_URL" =~ ^git@github\.com: ]]; then
         echo "Origin remote URL is already using SSH for GitHub:"
         run_cmd "git remote -v"
    else
        echo "Origin remote URL is not a standard GitHub HTTPS or SSH format:"
        run_cmd "git remote -v"
        yellow "Skipping automatic update. Please update manually if needed."
    fi
fi


# Step 9: Final reminder
green "\nStep 9: You’re now ready to push! 🎉"
echo "To commit changes and push, run the following commands:"
green "git add ."
green "git commit -m \"your message\""
green "git push"
