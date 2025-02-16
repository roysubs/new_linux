#!/bin/bash

# Check if a file argument is provided
if [[ -z "$1" ]]; then
    echo "Usage: $0 <image_file>"
    exit 1
fi

FILE="$1"

# Ensure the file exists
if [[ ! -f "$FILE" ]]; then
    echo "Error: File '$FILE' not found!"
    exit 1
fi

# Install required packages if not already installed
if ! command -v jp2a &>/dev/null; then
    echo "Installing jp2a..."
    sudo apt update && sudo apt install -y jp2a
fi

if ! command -v img2txt &>/dev/null; then
    echo "Installing caca-utils..."
    sudo apt install -y caca-utils
fi

# Convert image to ASCII art
echo "Processing image to ASCII..."
jp2a --color "$FILE"

# Alternative: Uncomment the line below if you prefer img2txt
# img2txt --gamma=0.6 --width=80 "$FILE"

