#!/bin/bash

# Script to install popular dungeon crawl games

# Update the package list
echo "Updating package list..."
sudo apt update -y

# Install dependencies for all games (if needed)
echo "Installing general dependencies..."
sudo apt install -y build-essential wget git curl libncurses5-dev

# 1. Dungeon Crawl Stone Soup (DCSS)
echo "Installing Dungeon Crawl Stone Soup (DCSS)..."
sudo apt install -y crawl

# 2. Tales of Maj'Eyal (ToME)
echo "Installing Tales of Maj'Eyal (ToME)..."
# Download the latest ToME package
wget https://te4.org/dl/tome/tome-1.7.6-linux64.tar.bz2 -P /tmp
# Extract and install
tar -xjf /tmp/tome-1.7.6-linux64.tar.bz2 -C /opt
# Create a symlink for easy access
sudo ln -s /opt/tome/tome /usr/local/bin/tome

# 3. Cataclysm: Dark Days Ahead
echo "Installing Cataclysm: Dark Days Ahead..."
# Clone the repository and compile
git clone https://github.com/CleverRaven/Cataclysm-DDA.git /opt/cataclysm-dda
cd /opt/cataclysm-dda
# Compile the game
make release
# Create a symlink for easy access
sudo ln -s /opt/cataclysm-dda/cataclysm-tiles /usr/local/bin/cataclysm

# 4. Angband
echo "Installing Angband..."
sudo apt install -y angband

# 5. Infra Arcana
echo "Installing Infra Arcana..."
# Download Infra Arcana
wget https://raw.githubusercontent.com/chaosvolt/infraarcana/master/linux/infraarcana-linux.zip -P /tmp
# Extract the archive
unzip /tmp/infraarcana-linux.zip -d /opt
# Create a symlink for easy access
sudo ln -s /opt/infraarcana-linux/infraarcana /usr/local/bin/infraarcana

# Finished
echo "Installation of dungeon crawl games is complete. You can now play the games by typing their respective commands (e.g., 'crawl', 'tome', 'cataclysm', 'angband', 'infraarcana')."

