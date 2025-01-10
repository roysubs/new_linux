#!/bin/bash

# Color codes for text formatting
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
WHITE='\033[0;37m'
NC='\033[0m' # No color

echo
echo "This script will guide you step by step to set up secure HTTPS authentication for GitHub."
echo "Using HTTPS has the following format for cloning and pushing:"
echo -e "Git clone with HTTPS URL:  ${GREEN}git clone https://github.com/<user>/<repo>.git${NC}"
echo -e "Git push via HTTPS:        ${GREEN}git push origin main${NC}"
echo

# Step 1: Install Git (if not installed)
echo -e "${YELLOW}Step 1: Ensuring that Git is installed.${NC}"
if ! command -v git &> /dev/null; then
    echo "Git is not installed. Installing Git..."
    sudo apt update
    sudo apt install -y git
else
    echo "Git is already installed."
fi
echo

# Step 2: Install Git Credential Manager (if not installed)
echo -e "${YELLOW}Step 2: Ensuring that Git Credential Manager is installed.${NC}"
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

# Step 3: Remove any existing conflicting credential helpers
echo -e "${YELLOW}Step 3: Cleaning up existing conflicting credential helpers.${NC}"
git config --global --unset-all credential.helper
git config --global credential.helper manager-core
echo "Conflicting helpers removed and 'manager-core' set."
echo

# Step 4: Configure Git with your name and email
echo -e "${YELLOW}Step 4: Configuring Git with your name and email.${NC}"
read -p "Enter your full name: " git_name
git config --global user.name "$git_name"

read -p "Enter your email address: " git_email
git config --global user.email "$git_email"
echo "Git configuration updated with your name and email."
echo

# Step 5: Set up GitHub Personal Access Token
echo -e "${YELLOW}Step 5: Setting up authentication with GitHub.${NC}"
echo -e "Generate a Personal Access Token (PAT) at: ${GREEN}https://github.com/settings/tokens${NC}"
echo "Ensure the token has scopes like 'repo' for private repositories."
echo -e "${WHITE}When prompted during 'git push', use your GitHub username and paste the PAT as your password.${NC}"
git-credential-manager configure
echo "Git Credential Manager is now ready to store credentials securely."
echo

# Step 6: Cloning a repository using HTTPS.
echo -e "${YELLOW}Step 6: Cloning a repository using HTTPS.${NC}"
echo "To clone a repository using HTTPS, follow these steps:"
echo "1. Go to a GitHub repository and click the green 'Code' button."
echo "2. Copy the HTTPS URL (e.g., https://github.com/<user>/<repo>.git)."
echo -e "${WHITE}You will use this URL in the following command to clone the repository:${NC}"
echo -e "${GREEN}git clone https://github.com/<user>/<repo>.git${NC}"
echo
echo "3. During the clone operation, Git Credential Manager will prompt you for your GitHub username and password."
echo "4. For your password, paste the Personal Access Token (PAT) that you generated in Step 5."
echo
echo "Once the repository is cloned, you can make changes and perform Git operations such as 'git push' without re-entering your PAT."
echo -e "You can push to the repository with: ${GREEN}git push origin main${NC}"

echo

echo -e "${GREEN}HTTPS authentication for GitHub is now set up and working on this computer.${NC}"
echo "You can use Git commands like 'git add .', 'git commit -m \"message\"', 'git push', etc."
echo "Your credentials are securely managed with Git Credential Manager."

# Detailed breakdown of the process:
# When you run git push for the first time, Git will prompt you for your GitHub
# username and password.
#
# For the password: You will paste your Personal Access Token (PAT), which you
# generated in Step 5, instead of using your GitHub password.
#
# Storing credentials securely:
# After you enter your PAT, the Git Credential Manager will securely store it in
# a local, encrypted store called manager-core. This is a secure storage system
# that handles credentials, ensuring that they are not stored in plaintext.
#
# Future Git operations:
# Once the PAT is stored, you will not be prompted again for the PAT when
# performing Git operations (e.g., git push) for that user on that specific machine.
# The credentials are cached and will be used automatically by Git Credential
# Manager for subsequent Git operations (like git push), as long as the stored PAT
# is valid.
#
# Expiration of the PAT:
# If your PAT expires or you revoke it, you will need to re-enter a new PAT. At
# that point, the process will repeat, and the new token will be stored securely.
#
# In summary, once you've entered your PAT during the first git push, you will
# not need to re-enter it for any future git push operations on this machine.
# The credential manager securely handles the authentication for you going forward.

# You need git-credential-manager (GCM) for securely storing your credentials. Here's why:
# What git-credential-manager does:
# Secure credential storage: GCM manages your GitHub Personal Access Token (PAT)
# securely in an encrypted store (like the manager-core backend). This ensures that
# you don't have to store the PAT in plaintext and that it's protected.
#
# Credential caching and management: GCM ensures you don't need to manually
# re-enter your PAT every time you perform a Git operation like git push.
#
# What happens without git-credential-manager:
# Without git-credential-manager, Git won't have a secure way to store your
# credentials. You would either have to manually provide your PAT every time you
# push or use another credential helper like git-credential-cache, which stores
# credentials temporarily in memory (but not encrypted). You could also use
# git-credential-store, but that stores credentials in plaintext in a
# .git-credentials file, which is insecure and not recommended.
#
# How git-credential-manager integrates:
# The git-credential-manager configure command sets up GCM to manage your
# credentials securely. This is the key step that ensures your credentials are
# stored in an encrypted store. After GCM is configured, Git uses it to store and
# retrieve credentials without prompting you again for the PAT (as long as it's
# still valid).
#
# Can it be done without GCM?
# Technically, you can use other methods like git-credential-cache or
# git-credential-store, but they are less secure. git-credential-manager is the
# recommended and secure method for handling credentials because it provides an
# encrypted, persistent, and safe solution to store your credentials.

# git-credential-manager normally expects a GUI environment and secretservice
# If that is not there, we have to configure a terminal-only based secure PAT storage
# git config --global --unset-all credential.helper
# git config --global credential.helper manager-core
# git config --global --get-all credential.helper
#
# ~/.gitconfig  should look like this:
#
# [user]
#     email = roysubs@hotmail.com
#     name = roysubs
# [credential]
#     helper = manager-core
#     credentialStore = cache
# [credential "https://dev.azure.com"]
#     useHttpPath = true
