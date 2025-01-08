#!/bin/bash

# Variables
REPO_URL="https://github.com/odditica/fiTD.git"
REPO_DIR="fiTD"

# Clone the repository
echo "Cloning the FiTD repository..."
git clone $REPO_URL

# Change to the repository directory
cd $REPO_DIR

# Install dependencies
echo "Installing dependencies..."
sudo apt-get update
sudo apt-get install -y cmake catch2 libncurses5-dev doxygen

# Apply fixes to source files
echo "Applying fixes to source files..."
sed -i 's/mvwprintw(/mvwprintw(stdscr, /' src/CGameGraphics.cpp
sed -i 's/mvwaddchstr(/mvwaddchstr(stdscr, /' src/CGfx.cpp

# Create a build directory and compile the game
echo "Building FiTD..."
mkdir -p build
cd build
cmake ..
make

# Check if the build was successful
if [ $? -ne 0 ]; then
    echo "Build failed. Please check the error messages above."
    exit 1
fi

# Generate documentation
echo "Generating documentation..."
make doc

# Check if documentation generation was successful
if [ $? -ne 0 ]; then
    echo "Documentation generation failed. Please check the error messages above."
    exit 1
fi

# Provide instructions to run the game
echo "You can now run FiTD using the following commands:"
echo "cd build"
echo "./fitd"

echo "Installation script completed."

