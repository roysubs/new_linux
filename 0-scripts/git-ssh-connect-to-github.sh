#!/bin/bash

# Connect a git project to github securely with ssh and switch the project
# to SSH if it was cloned via HTTPS. SSH is probably easier and more widely
# used than HTTPS.

# set -e ensures that the script exits immediately if a command exits with a non-zero status.
# Exceptions are made for specific commands where failure is expected or handled (like the ssh-add check below).
set -e

# Color functions
red() { echo -e "\033[1;31m$*\033[0m"; }
green() { echo -e "\033[1;32m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }

# Function to run commands and show them
run_cmd() {
    green "\$ $*"
    # Use eval to correctly handle commands with quotes or variables like the ssh-agent eval
    eval "$@"
    # We generally rely on set -e, but explicit checks can be added if needed
}

# Function to pause with a message
pause_msg() {
    echo -e "\n\033[1;33m$1\033[0m"
    # Use /dev/tty for read to ensure it reads from the terminal even if stdin is redirected
    read -rp "Press Enter to continue..." </dev/tty
}

echo
yellow "=== GitHub SSH Setup & connect to GitHub ==="
echo "Connect a git project to GitHub securely with SSH, and switch to the connection to SSH if"
echo "it was cloned using HTTPS (generally easier and more widely used than HTTPS)."
echo "Generate SSH keys if required:"
green "   ssh-keygen -t ed25519 -C <email>;  cat ~/.ssh/id_ed25519.pub"
echo "Start SSH agent:"
green "   eval \"\$(ssh-agent -s)\""
echo "Test SSH connection to GitHub:  ssh -T git@github.com"
echo "Check if the project was cloned using HTTPS and if so, switch to SSH with:"
green "   git remote set-url origin git@github.com:<user>/<repo>.git"
pause_msg ""

# Step 1: Check/Set Git User Name and Email
green "\nStep 1: Checking Git user name and email..."

# Use || echo "" to prevent git config from failing the script if not set,
# allowing the check [ -z "$VAR" ] to work correctly under set -e.
GIT_USER_NAME=$(git config --global user.name || echo "")
GIT_USER_EMAIL=$(git config --global user.email || echo "")

echo "Current Git User Name: ${GIT_USER_NAME:-Not Set}" # Use :- to display "Not Set" if variable is empty
echo "Current Git User Email: ${GIT_USER_EMAIL:-Not Set}"

if [ -z "$GIT_USER_NAME" ] || [ -z "$GIT_USER_EMAIL" ]; then
    red "\nGit user name or email is not set globally. These are needed for SSH key generation and commits."
    # Prompt the user for input, reading from /dev/tty for interactive prompt
    read -rp "Do you want to set them now? (y/n): " -n 1 -r </dev/tty # Read single char
    echo # Add a newline after the read

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Okay, let's set them."

        NEW_USER_NAME=""
        # Loop until a non-empty name is provided
        while [ -z "$NEW_USER_NAME" ]; do
            read -rp "Enter your Git user name: " NEW_USER_NAME </dev/tty
            if [ -z "$NEW_USER_NAME" ]; then
                red "User name cannot be empty. Please try again."
            fi
        done

        NEW_USER_EMAIL=""
        # Simple email format check (basic, not comprehensive)
        # This regex checks for something@something.something
        EMAIL_REGEX="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
        # Loop until a valid email format is provided
        while [[ ! "$NEW_USER_EMAIL" =~ $EMAIL_REGEX ]]; do
            read -rp "Enter your Git user email: " NEW_USER_EMAIL </dev/tty
            if [[ ! "$NEW_USER_EMAIL" =~ $EMAIL_REGEX ]]; then
                red "Invalid email format. Please try again."
            fi
        done


        # Use run_cmd for consistency and showing the command
        # Run commands and check their success explicitly before proceeding
        if run_cmd "git config --global user.name \"$NEW_USER_NAME\""; then
            green "✅ Git user name set."
        else
            red "❌ Failed to set Git user name. Exiting."
            exit 1
        fi

        if run_cmd "git config --global user.email \"$NEW_USER_EMAIL\""; then
            green "✅ Git user email set."
        else
            red "❌ Failed to set Git user email. Exiting."
            exit 1
        fi

    elif [[ $REPLY =~ ^[Nn]$ ]]; then
        red "\nGit user name and email are required to proceed. Exiting."
        exit 1
    else
        red "\nInvalid input. Please run the script again and enter 'y' or 'n'."
        exit 1 # Exit on invalid input
    fi
else
    green "✅ Git user name and email are already set globally."
fi

# Pause before continuing to the next steps
pause_msg ""

# The rest of the script steps will now be renumbered
# Step 2 (formerly Step 1): Check if Git is installed
green "\nStep 2: Checking for Git installation..."
if ! command -v git &>/dev/null; then
    red "Error: Git not found. Please install Git before proceeding."
    exit 1
fi
run_cmd "git --version"


# Step 3 (formerly Step 2): Check existing SSH keys
green "\nStep 3: Checking for existing SSH keys..."
ls -l ~/.ssh/id_*.pub 2>/dev/null || echo "No SSH public keys found."

# Step 4 (formerly Step 3): Generate SSH key if missing
green "\nStep 4: Checking/Generating SSH key..." # Corrected typo "Generatign"
if [ ! -f ~/.ssh/id_ed25519 ]; then
    green "No ed25519 key found. Generating one..."
    # We already checked and potentially set the email in Step 1, so we can retrieve it again
    GIT_USER_EMAIL=$(git config --global user.email)

    # Use run_cmd to show the command, but run ssh-keygen directly for interactive prompts
    green "\$ ssh-keygen -t ed25519 -C \"$GIT_USER_EMAIL\""
    # Run ssh-keygen directly so interactive prompts work.
    ssh-keygen -t ed25519 -C "$GIT_USER_EMAIL"
    KEYGEN_EXIT_STATUS=$? # Capture exit status immediately

    # Check if key generation was successful (exit status 0 and file exists)
    if [ $KEYGEN_EXIT_STATUS -ne 0 ] || [ ! -f ~/.ssh/id_ed25519 ]; then
        red "Error: SSH key generation failed or key file not found."
        # Provide more info if keygen failed
        if [ $KEYGEN_EXIT_STATUS -ne 0 ]; then
            red "ssh-keygen command exited with status: $KEYGEN_EXIT_STATUS"
        fi
        exit 1
    fi
else
    echo "SSH key already exists at ~/.ssh/id_ed25519"
fi


# Step 5 (formerly Step 4): Start ssh-agent and add key
green "\nStep 5: Starting ssh-agent and adding key..."
# Note: eval "$(ssh-agent -s)" needs to be run directly in your shell
# or sourced from a script for its environment variables to persist beyond this script.
# However, for the subsequent `ssh-add` and `ssh -T` *within this same script execution*,
# the environment should be inherited correctly.
run_cmd 'eval "$(ssh-agent -s)"'
# Use || true here to prevent set -e from exiting if the key was already added
# (ssh-add exits with 1 if the key is already present) or if the agent wasn't started correctly.
# We still want to see the output of ssh-add even if it fails, so run it via run_cmd but keep the || true
run_cmd 'ssh-add ~/.ssh/id_ed25519 || true'


# Step 6 (formerly Step 5): Verify SSH agent is running and key is added
green "\nStep 6: Verifying SSH agent and key..."
# Check if ssh-add -l runs successfully (agent is accessible)
# and if its output contains the expected key type (ED25519).
# We redirect stderr to /dev/null for the check itself to avoid "Could not open connection"
# messages cluttering output when the agent is indeed not running or key not loaded correctly.
if ssh-add -l 2>/dev/null | grep -q ED25519; then
    green "SSH agent is running and key 'id_ed25519' (ED25519) is loaded successfully."
else
    # Run ssh-add -l again without suppressing output so the user can see the error message if any
    # Use || true to prevent exiting due to set -e if ssh-add -l fails
    run_cmd 'ssh-add -l || true' # Use run_cmd here too
    red "\nWarning: Could not verify SSH agent is running or key 'id_ed25519' is loaded."
    echo "This means subsequent SSH operations (like push/pull) might fail."
    echo "Ensure 'eval \"\$(ssh-agent -s)\"' was run in your current shell and your key was added manually if needed."
fi


# Step 7 (formerly Step 6): Show public key for GitHub
green "\nStep 7: Displaying your SSH public key:"
if [ -f ~/.ssh/id_ed25519.pub ]; then
    cat ~/.ssh/id_ed25519.pub
else
    red "Error: SSH public key file not found at ~/.ssh/id_ed25519.pub"
    # We don't exit here, maybe the user just needs the other steps.
fi

pause_msg "📋 Copy the key displayed above, then go to:\nhttps://github.com → Settings → SSH and GPG keys → New SSH key.\nPaste the key there and save it before continuing."

# Step 8 (formerly Step 7): Test SSH connection
green "\nStep 8: Testing SSH connection to GitHub..."
# Use || true because ssh -T is expected to exit with 1 if successful authentication happens but no PTY is allocated (which is normal).
# It will exit with a different code on authentication failure or other errors.
# We just want to see the output and not stop the script if the exit code is 1.
run_cmd "ssh -T git@github.com || true"

# Step 9 (formerly Step 8): Check or update Git remote (Automatic HTTPS to SSH conversion)
green "\nStep 9: Checking Git remote URL..."

# Check if we are in a git repository first
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    yellow "Warning: Not currently in a Git repository."
    echo "Skipping remote URL check/update."
else
    # Move to the repository root directory safely
    REPO_ROOT=$(git rev-parse --show-toplevel)
    if [ $? -ne 0 ]; then
      red "Error: Could not determine repository root. Skipping remote URL check/update."
    else
        cd "$REPO_ROOT" || { red "Error: Could not navigate to repository root."; exit 1; }

        # Use || echo "" to handle case where 'origin' remote doesn't exist
        REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")

        if [ -z "$REMOTE_URL" ]; then
            yellow "No 'origin' remote URL found in this repository."
            echo "Add a remote URL using: git remote add origin <url>"
        # Use a less strict regex to match HTTPS GitHub URLs, capturing user and repo
        elif [[ "$REMOTE_URL" =~ ^https://github\.com/([^/]+)/([^/]+)(\.git)? ]]; then # Added optional .git
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
    fi # End of check for REPO_ROOT success
fi


# Step 10 (formerly Step 9): Final reminder
green "\nStep 10: You’re now ready to push! 🎉" # Corrected step number
echo "To commit changes and push, run the following commands:"
green "git add ."
green "git commit -m \"your message\""
green "git push"
