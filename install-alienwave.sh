#!/bin/bash

# Ensure the script exits on errors
set -e

# Install required dependencies
echo "Installing dependencies..."
sudo apt-get update
sudo apt-get install -y libncurses5-dev libncursesw5-dev

# Find the Makefile
MAKEFILE_DIR=$(find . -type f -name "Makefile" -o -name "makefile" -o -name "GNUmakefile" | head -n 1 | xargs dirname)

if [[ -z "$MAKEFILE_DIR" ]]; then
  echo "Error: No Makefile found in the source tree."
  echo "Ensure you have the correct source files and try again."
  exit 1
fi

# Navigate to the Makefile directory
cd "$MAKEFILE_DIR"
echo "Found Makefile in $(pwd)."

# Build and install
echo "Running make..."
sudo make

echo "Installing the program..."
sudo make install

# Verify the executable exists before copying
if [[ -f alienwave ]]; then
  echo "Copying the executable to /usr/games..."
  sudo cp alienwave /usr/games
else
  echo "Error: Executable 'alienwave' not found. Build might have failed."
  exit 1
fi

echo "Installation completed successfully!"

