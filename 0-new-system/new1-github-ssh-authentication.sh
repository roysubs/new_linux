#!/bin/bash

# Color codes for text formatting
GREEN='\033[0;32m'
WHITE='\033[0;37m'
NC='\033[0m' # No color

echo
echo "This script will guide you step by step to set up SSH authentication for GitHub."
echo "Using SSH has a slightly different format than using HTTPS:"
echo -e "Git clone with HTTPS URL:  ${GREEN}git clone https://github.com/<user>/<repo>.git${NC}"
echo -e "Git clone with SSH path:   ${GREEN}git clone git@github.com:<user>/<repo>.git${NC}"
echo

# Step 1: Generate SSH Keypair
echo "Step 1: Generating an SSH keypair."
echo "We recommend using 'ed25519' for better security and performance."
echo "Available key types are:"
echo "  1. ed25519 (default)"
echo "  2. rsa"

# Prompt user for key type
read -p "Enter the desired key type (default: ed25519): " key_type
key_type=${key_type:-ed25519}
if [[ "$key_type" != "ed25519" && "$key_type" != "rsa" ]]; then
    echo "Invalid key type. Please choose 'ed25519' or 'rsa'."
    exit 1
fi

# Prompt user for key file path
read -p "Enter the desired key file path (default: ~/.ssh/id_$key_type): " key_path
key_path=${key_path:-~/.ssh/id_$key_type}

# Check if the key already exists
if [ -f "$key_path" ]; then
    echo "An SSH keypair already exists at $key_path. Skipping key generation."
    exit 0
fi

echo "Press Enter to continue or CTRL+C to exit."
read
echo -e "Running: ${GREEN}ssh-keygen -t $key_type -C 'your_email@example.com' -f $key_path${NC}"
echo "Please enter your email address (this will be used as a comment in the SSH key):"
read -p "Email: " user_email
ssh-keygen -t "$key_type" -C "$user_email" -f "$key_path"
echo
echo "SSH keypair created! Moving to the next step."
echo

# Step 2: Start the SSH Agent
echo "Step 2: Starting the SSH agent."
echo "The SSH agent helps manage your SSH keys for authentication."
echo -e "Running: ${GREEN}eval \$(ssh-agent -s)${NC}"
eval "$(ssh-agent -s)"
echo
echo "SSH agent started successfully."
echo

# Step 3: Add Key to SSH Agent
echo "Step 3: Adding your private key to the SSH agent."
echo "We'll also configure your SSH client to automatically add keys."
echo -e "Editing ${GREEN}~/.ssh/config${NC} file to include necessary configurations."
mkdir -p ~/.ssh
echo -e "Running: ${GREEN}echo -e \"Host *\\n    AddKeysToAgent yes\\n    IdentityFile $key_path\" > ~/.ssh/config${NC}"
echo -e "Host *\n    AddKeysToAgent yes\n    IdentityFile $key_path" > ~/.ssh/config
echo
echo "Configuration updated. Adding the private key to the SSH agent."
echo -e "Running: ${GREEN}ssh-add $key_path${NC}"
ssh-add "$key_path"
echo "Key added successfully."
echo

# Step 4: Show Public Key
echo "Step 4: Displaying your public SSH key."
echo "This is the key you'll need to add to your GitHub account."
echo -e "Running: ${GREEN}cat $key_path.pub${NC}"
cat "$key_path.pub"
echo
echo "Copy the above key and add it to your GitHub account."
echo "Go to: https://github.com -> Settings -> SSH and GPG keys -> New SSH key."
echo "Paste the key and save it."
echo "Press Enter once you've completed this step."
read
echo

# Step 5: Test SSH Connection
echo "Step 5: Testing the SSH connection to GitHub."
echo "When prompted by the ssh -T, type yes to perform the test."
echo -e "Running: ${GREEN}ssh -T git@github.com${NC}"
ssh -T git@github.com
echo
echo "If you see a message like 'You've successfully authenticated', then everything is set up correctly."
echo

# Step 6: Clone a Repository
echo "Step 6: Cloning a repository using SSH."
echo "Go to a GitHub repository and select the green 'Code' button."
echo "Switch to SSH and copy the SSH URL (e.g., git@github.com:<user>/<repo>.git)."
echo "Paste the SSH URL below:"
read -p "SSH URL: " repo_url
echo -e "Running: ${GREEN}git clone $repo_url${NC}"
git clone "$repo_url"
repo_name=$(basename "$repo_url" .git)
echo
echo "Repository cloned! Navigating into the repository folder."
echo -e "Running: ${GREEN}cd $repo_name${NC}"
cd "$repo_name"
echo -e "Running: ${GREEN}git remote -v${NC}"
git remote -v
echo

echo "SSH authentication for this user on this computer is now set up and working with GitHub."
echo "To setup a repo for SSH authentication..."
echo "Set configuration:"
echo -e "   ${GREEN}git config --global user.email \"you@example.com\"${NC}"
echo -e "   ${GREEN}git config --global user.name \"your name\"${NC}"
echo "Create the repo on GitHub, then clone it here:"
echo -e "   ${GREEN}git clone git@github.com:<user>/<repo>.git${NC}"
echo "After that, you can then use Git commands 'git add .', 'git commit -m \"comment\"', 'git push' etc."
echo

