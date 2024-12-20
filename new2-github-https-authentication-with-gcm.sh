#!/bin/bash

# Color codes for text formatting
GREEN='\033[0;32m'
WHITE='\033[0;37m'
NC='\033[0m' # No color

echo
echo "This script will guide you step by step to set up secure HTTPS authentication for GitHub."
echo "Using HTTPS has the following format for cloning and pushing:"
echo -e "Git clone with HTTPS URL:  ${GREEN}git clone https://github.com/<user>/<repo>.git${NC}"
echo -e "Git push via HTTPS:        ${GREEN}git push https://github.com/<user>/<repo>.git${NC}"
echo

# Step 1: Install Git (if not installed)
echo "Step 1: Ensuring that Git is installed."
if ! command -v git &> /dev/null; then
    echo "Git is not installed. Installing Git..."
    sudo apt update
    sudo apt install -y git
else
    echo "Git is already installed."
fi
echo

# Step 2: Install Git Credential Manager (if not installed)
echo "Step 2: Ensuring that Git Credential Manager is installed."
if ! command -v git-credential-manager &> /dev/null; then
    echo "Git Credential Manager is not installed. Installing Git Credential Manager..."
    sudo apt update
    sudo apt install -y jq curl  # Ensure dependencies
    api_url="https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest"
    deb_url=$(curl -s "$api_url" | jq -r '.assets[] | select(.name | test(".deb$")) | .browser_download_url')

    if [ -z "$deb_url" ]; then
        echo "Error: Could not find the .deb package URL. Please check your network connection."
        exit 1
    fi

    curl -L "$deb_url" -o gcm.deb
    sudo dpkg -i gcm.deb
    rm gcm.deb
else
    echo "Git Credential Manager is already installed."
fi
echo

# Step 3: Configure Git with your credentials
echo "Step 3: Configuring Git with your name and email."
read -p "Enter your full name: " git_name
git config --global user.name "$git_name"

read -p "Enter your email address: " git_email
git config --global user.email "$git_email"
echo "Git configuration updated with your name and email."
echo

# Step 4: Set up GitHub Personal Access Token
echo "Step 4: Set up a Personal Access Token (PAT) for authentication."
echo "GitHub requires a Personal Access Token instead of a password for HTTPS operations."
echo "Generate a PAT at: ${GREEN}https://github.com/settings/tokens${NC}"
echo "Ensure the token has the appropriate scopes (e.g., repo, workflow)."
read -sp "Enter your Personal Access Token: " github_token
echo
git-credential-manager configure

echo "Storing your credentials securely with Git Credential Manager."
echo "$github_token" | git credential approve
echo "Credentials stored securely."
echo

# Step 5: Clone a repository using HTTPS
echo "Step 5: Cloning a repository using HTTPS."
echo "Go to a GitHub repository and select the green 'Code' button."
echo "Copy the HTTPS URL (e.g., https://github.com/<user>/<repo>.git)."
read -p "HTTPS URL: " repo_url
git clone "$repo_url"
repo_name=$(basename "$repo_url" .git)
echo "Repository cloned successfully into: $repo_name"
echo

# Step 6: Test Git operations (push/pull)
echo "Step 6: Testing secure Git operations over HTTPS."
cd "$repo_name" || { echo "Failed to enter repository directory."; exit 1; }
echo "Creating an initial commit."
touch README.md
git add README.md
git commit -m "Initial commit"
git push
echo "Push operation completed successfully."
echo

echo -e "${GREEN}HTTPS authentication for GitHub is now set up and working on this computer.${NC}"
echo "You can use Git commands like 'git add .', 'git commit -m \"message\"', 'git push', etc."
echo "Your credentials are securely managed with Git Credential Manager."

