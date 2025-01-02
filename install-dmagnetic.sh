#!/bin/bash

# Variables
DMAGNETIC_URL="https://www.dettus.net/dMagnetic/dMagnetic_0.37.tar.bz2"
DMAGNETIC_ARCHIVE="dMagnetic_0.37.tar.bz2"
DMAGNETIC_DIR="dMagnetic_0.37"

# Adventure game URLs
PAWN_URL="https://archive.org/download/moofaday_The_Pawn/The%20Pawn%20v2.3%20%28moof-a-day%20collection%29.zip"
GUILD_URL="https://archive.org/download/Guild_of_Thieves_The_1987_Magnetic_Scrolls_Side_A/Guild_of_Thieves_The_1987_Magnetic_Scrolls_Side_A.zip"
JINXTER_URL="https://archive.org/download/Jinxter_1987_Magnetic_Scrolls_Side_A/Jinxter_1987_Magnetic_Scrolls_Side_A.zip"
FISH_URL="https://arcadespot.com/game/the-fish-files/"

# Download dMagnetic
echo "Downloading dMagnetic..."
wget $DMAGNETIC_URL -O $DMAGNETIC_ARCHIVE

# Extract the archive
echo "Extracting dMagnetic..."
tar xvfj $DMAGNETIC_ARCHIVE

# Change to the extracted directory
cd $DMAGNETIC_DIR

# Compile dMagnetic
echo "Compiling dMagnetic..."
make

# Check if compilation was successful
if [ -f dMagnetic ]; then
    echo "dMagnetic compiled successfully."
else
    echo "Compilation failed."
    exit 1
fi

# Download adventure games
echo "Downloading adventure games..."
wget $PAWN_URL -O pawn.zip
wget $GUILD_URL -O guild.zip
wget $JINXTER_URL -O jinxter.zip

# Unzip the downloaded games
echo "Unzipping adventure games..."
unzip pawn.zip -d pawn
unzip guild.zip -d guild
unzip jinxter.zip -d jinxter

# Clean up zip files
rm pawn.zip guild.zip jinxter.zip

# Provide information about running dMagnetic
echo "You can now run dMagnetic using the following commands for each game:"
echo "./dMagnetic -mag <path_to_mag_file> -gfx <path_to_gfx_file>"

# Clean up the downloaded archive
cd ..
rm $DMAGNETIC_ARCHIVE

echo "Installation script completed."

