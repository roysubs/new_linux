#!/bin/bash

echo "Starting GitHub SSH setup script..."

# Step 1: Display default Git email and username
default_name=$(git config --global user.name)
default_email=$(git config --global user.email)

echo "Current Git configuration:"
echo "Username: $default_name"
echo "Email: $default_email"

read -p "Is this information correct? (y/n): " confirm

if [ "$confirm" != "y" ]; then
    read -p "Enter your Git username: " new_name
    read -p "Enter your Git email: " new_email
    git config --global user.name "$new_name"
    git config --global user.email "$new_email"
    echo "Git username and email updated."
    default_email=$new_email
else
    echo "Using existing Git configuration."
fi

# Step 2: Check if inside a git project
echo "Checking if you are inside a git project..."
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "You are inside a git project."
else
    echo "You are not inside a git project. Please navigate to a git project directory and rerun the script."
    exit 1
fi

# Step 3: Check for existing SSH keys
echo "Checking for existing SSH keys..."
if [ -f ~/.ssh/id_ed25519 ] || [ -f ~/.ssh/id_rsa ]; then
    echo "SSH keys found."
else
    echo "No SSH keys found. Generating new SSH key..."
    ssh-keygen -t ed25519 -C "$default_email"
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519
    echo "SSH key generated and added to ssh-agent."
fi

# Step 4: Check if SSH key is added to GitHub
echo "Checking if SSH key is added to GitHub..."
SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "SSH key is already added to GitHub."
else
    echo "SSH key is not added to GitHub. Please add the following SSH key to your GitHub account:"
    echo "$SSH_KEY"
    echo "Go to https://github.com/settings/keys, click 'New SSH key', paste the key, and click 'Add SSH key'."
    read -p "Press Enter after you have added the SSH key to GitHub..."
fi

# Step 5: Test SSH connection to GitHub
echo "Testing SSH connection to GitHub..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "SSH connection to GitHub successful."
else
    echo "SSH connection to GitHub failed. Please check your SSH key and try again."
    exit 1
fi

# Step 6: Add, commit, and push changes
echo "Adding, committing, and pushing changes..."
git add .
git commit -m "Various"
git push origin main
echo "Changes pushed to GitHub."

echo "Setup complete. You are fully connected and ready to push changes."

