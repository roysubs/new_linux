#!/bin/bash

# github-gh-auth-login.sh
# This script helps you log into GitHub CLI (`gh`) using a Personal Access Token (PAT),
# avoiding the need for a web browser.

clear
echo -e "GitHub CLI Authentication Script\n=================================="
echo -e "\nThis script will guide you through logging into GitHub CLI (gh)\nwithout needing a web browser."
echo -e "Instead, we will use a Personal Access Token (PAT).\n"
read -p "Press Enter to continue..."

# Step 1: Explain why a PAT is needed
echo -e "\nStep 1: Generate a Personal Access Token (PAT)"
echo -e "---------------------------------------------"
echo -e "Since you are using SSH from a remote terminal, GitHub CLI would normally\ntry to open a web browser, which we want to avoid."
echo -e "Instead, we'll use a PAT to authenticate.\n"
echo -e "Follow these steps to generate a PAT:"
echo -e "  1. Open GitHub in a browser on your local machine."
echo -e "  2. Go to: https://github.com/settings/tokens"
echo -e "  3. Click 'Generate new token (classic)'."
echo -e "  4. Give it a name, like 'GitHub CLI Auth'."
echo -e "  5. Select the following permissions:"
echo -e "      - 'repo' (for repository access)"
echo -e "      - 'read:org' (if needed for organizational repositories)"
echo -e "      - 'write:public_key' (if using SSH authentication)."
echo -e "  6. Click 'Generate token' and copy it."
echo -e "  7. Keep it safe! You will only see it once.\n"
read -p "Press Enter once you've generated the token..."

# Step 2: Use the token to authenticate
echo -e "\nStep 2: Authenticate GitHub CLI (`gh`) with the PAT"
echo -e "---------------------------------------------------"
echo -e "Now that you have your token, we will log in."
echo -e "When prompted, paste the token and press Enter.\n"

# Finally, run the `gh auth login` command
gh auth login --with-token

