#!/bin/bash

# Function to prompt user for confirmation
confirm_overwrite() {
    read -p "The 'umoria' directory already exists. Do you want to overwrite it? (yes/no): " response
    if [[ "$response" == "yes" ]]; then
        return 0
    else
        return 1
    fi
}

# Update package list and install dependencies
sudo apt update
sudo apt install -y git cmake g++ libncurses-dev

# Check if umoria directory exists and prompt for confirmation
if [ -d "umoria" ]; then
    if confirm_overwrite; then
        rm -rf umoria
    else
        echo "Installation aborted."
        exit 1
    fi
fi

# Clone the Umoria source code from GitHub
git clone https://github.com/dungeons-of-moria/umoria.git
cd umoria

# Create a build directory and configure the build with modified flags
mkdir -p build && cd build
CXXFLAGS="-Wno-format-truncation" cmake ..
make -j $(nproc)

# Check if the binary exists and move it along with data files to a directory in your home
if [ -f umoria/umoria ]; then
    mkdir -p ~/umoria
    cp umoria/umoria ~/umoria
    cp -r ../data ~/umoria

    # Create an empty scores.dat file if it doesn't exist
    if [ ! -f ~/umoria/data/scores.dat ]; then
        touch ~/umoria/data/scores.dat
    fi

    # Ensure appropriate file permissions
    chmod 644 ~/umoria/data/scores.dat

    echo "Umoria has been successfully installed in ~/umoria"
    echo "To play the game, navigate to the ~/umoria directory and run ./umoria"
else
    echo "Installation failed. The binary 'umoria' was not found."
    echo "Please check the build logs for any errors and try again."
fi

