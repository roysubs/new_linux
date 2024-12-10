#!/bin/bash

# Update package list
echo "Updating package list..."
sudo apt update

# Install required dependencies
echo "Installing dependencies..."
sudo apt install -y python3 python3-pip git build-essential

# Clone Unimatrix repository (replace with actual URL)
REPO_URL="https://github.com/will8211/unimatrix"
echo "Cloning Unimatrix repository from $REPO_URL..."
git clone "$REPO_URL"

# Change directory to Unimatrix
cd unimatrix || { echo "Failed to enter unimatrix directory"; exit 1; }

# Install Python dependencies if requirements.txt exists
if [ -f "requirements.txt" ]; then
    echo "Installing Python dependencies..."
    pip3 install -r requirements.txt
else
    echo "No requirements.txt found. Skipping Python dependencies installation."
fi

# Run the Unimatrix application (adjust command based on actual setup)
echo "Running Unimatrix..."
python3 unimatrix.py

# Or, if there is a different executable:
# ./unimatrix

