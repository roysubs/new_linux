#!/bin/bash

# Make sure python3 and git are present for unimatrix setup
echo "Updating package list..."
sudo apt update
echo "Installing dependencies..."
sudo apt install -y python3 python3-pip git # build-essential

# Clone Unimatrix repository
REPO_URL="https://github.com/will8211/unimatrix"
echo "Cloning Unimatrix repository from $REPO_URL to ~/unimatrix..."
git clone "$REPO_URL" "~/unimatrix"

# Change directory to Unimatrix
cd ~/unimatrix || { echo "Failed to enter unimatrix directory"; exit 1; }

# Install Python dependencies if requirements.txt exists
if [ -f "requirements.txt" ]; then
    echo "Installing Python dependencies..."
    pip3 install -r requirements.txt
else
    echo "No requirements.txt found. Skipping Python dependencies installation."
fi

# Install cmatrix and bb
sudo apt install cmatrix bb hollywood -y

# Run the Unimatrix application (adjust command based on actual setup)
echo "Running Unimatrix..."
python3 unimatrix.py
# Or, if there is a different executable:
# ./unimatrix

echo "
unimatrix, to run again, can setup
   alias unimatrix='python3 ~/unimatrix/unimatrix.py'

cmatrix

bb
"




