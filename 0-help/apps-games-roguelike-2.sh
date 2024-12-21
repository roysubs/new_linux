#!/bin/bash

# Script to install popular dungeon crawl games with user selection

# Function to display the game list with details
display_game_list() {
  echo "Available dungeon crawl games to install:"
  echo "-------------------------------------------------------------"
  
  games=(
    "Dungeon Crawl Stone Soup (DCSS)"
    "Tales of Maj'Eyal (ToME)"
    "Cataclysm: Dark Days Ahead"
    "Angband"
    "Infra Arcana"
    "Nethack"
    "Dungeonmans"
    "The Binding of Isaac: Rebirth"
    "Slasher's Keep"
    "UnNetHack"
    "Rogue"
    "Dwarf Fortress"
    "Zangband"
    "Tangledeep"
    "Caves of Qud"
  )
  
  details=(
    # Game details: name, size, source, url
    "A well-known classic roguelike.\n   Size: ~10MB\n   Maintained, GitHub repository.\n   Source: https://github.com/crawl/crawl\n   URL: https://www.dcss.eu/"
    "A deep, story-rich roguelike with tactical gameplay.\n   Size: ~100MB\n   Maintained, Official website.\n   Source: https://te4.org/dl/tome\n   URL: https://te4.org/"
    "A post-apocalyptic, survival roguelike.\n   Size: ~200MB\n   Maintained, GitHub repository.\n   Source: https://github.com/CleverRaven/Cataclysm-DDA\n   URL: https://cataclysmdda.org/"
    "A classic dungeon crawler with deep exploration.\n   Size: ~5MB\n   Maintained, GitHub repository.\n   Source: https://github.com/angband/angband\n   URL: https://angband.github.io/"
    "A gothic roguelike with exploration and combat.\n   Size: ~10MB\n   Maintained, GitHub repository.\n   Source: https://github.com/chaosvolt/infraarcana\n   URL: https://chaosvolt.github.io/infraarcana/"
    "A classic roguelike dungeon crawler with deep mechanics.\n   Size: ~20MB\n   Maintained, GitHub repository.\n   Source: https://github.com/NetHack/NetHack\n   URL: https://www.nethack.org/"
    "A roguelike with humor, progression, and a class system.\n   Size: ~200MB\n   Maintained, Official website.\n   Source: https://www.dungeonmans.com/\n   URL: https://www.dungeonmans.com/"
    "A modern roguelike with randomized dungeons.\n   Size: ~500MB\n   Maintained, Steam.\n   Source: https://store.steampowered.com/app/250900/The_Binding_of_Isaac_Rebirth/\n   URL: https://store.steampowered.com/app/250900/The_Binding_of_Isaac_Rebirth/"
    "A first-person dungeon crawler with roguelike elements.\n   Size: ~150MB\n   Maintained, Steam.\n   Source: https://store.steampowered.com/app/766760/Slashers_Keep/\n   URL: https://store.steampowered.com/app/766760/Slashers_Keep/"
    "A variant of Nethack with additional features.\n   Size: ~20MB\n   Maintained, GitHub repository.\n   Source: https://github.com/unnethack/unnethack\n   URL: https://github.com/unnethack/unnethack"
    "The original roguelike that started the genre.\n   Size: ~1MB\n   Maintained, GitHub repository.\n   Source: https://github.com/rogue/rogue\n   URL: https://github.com/rogue/rogue"
    "Massively complex with fortress and adventure modes.\n   Size: ~20MB\n   Maintained, Official website.\n   Source: https://www.bay12games.com/dwarves/\n   URL: https://www.bay12games.com/dwarves/"
    "A variant of Angband with more modern updates.\n   Size: ~10MB\n   Maintained, GitHub repository.\n   Source: https://github.com/Zangband/Zangband\n   URL: https://github.com/Zangband/Zangband"
    "A visually appealing roguelike with a casual tone.\n   Size: ~250MB\n   Maintained, Steam.\n   Source: https://store.steampowered.com/app/528220/Tangledeep/\n   URL: https://www.tangledeep.com/"
    "A sci-fi roguelike with narrative elements.\n   Size: ~500MB\n   Maintained, GitHub repository.\n   Source: https://github.com/cavesofqud/cavesofqud\n   URL: https://www.cavesofqud.com/"
  )
  
  # Display the numbered list
  for i in ${!games[@]}; do
    echo "$((i+1)). ${games[$i]}"
    echo -e "   ${details[$i]}"
    echo "-------------------------------------------------------------"
  done
}

# Function to install selected games
install_selected_games() {
  # Read user input
  read -p "Enter the number(s) of the games to install (e.g., 1,3 for games 1 and 3, or 0 for all): " input

  # Install the selected games
  if [[ "$input" == "0" ]]; then
    echo "Installing all games..."
    install_all_games
  else
    # Convert the input to an array of numbers
    IFS=',' read -ra games_to_install <<< "$input"
    for num in "${games_to_install[@]}"; do
      case $num in
        1) install_dcss ;;
        2) install_tome ;;
        3) install_cataclysm ;;
        4) install_angband ;;
        5) install_infraarcana ;;
        6) install_nethack ;;
        7) install_dungeonmans ;;
        8) install_bindingofisaac ;;
        9) install_slasherkeep ;;
        10) install_unnetHack ;;
        11) install_rogue ;;
        12) install_dwarffortress ;;
        13) install_zangband ;;
        14) install_tangledeep ;;
        15) install_cavesofqud ;;
        *) echo "Invalid number: $num" ;;
      esac
    done
  fi
}

# Install all games
install_all_games() {
  install_dcss
  install_tome
  install_cataclysm
  install_angband
  install_infraarcana
  install_nethack
  install_dungeonmans
  install_bindingofisaac
  install_slasherkeep
  install_unnetHack
  install_rogue
  install_dwarffortress
  install_zangband
  install_tangledeep
  install_cavesofqud
}

# Function to install Dungeon Crawl Stone Soup
install_dcss() {
  echo "Installing Dungeon Crawl Stone Soup (DCSS)..."
  sudo apt install -y crawl
}

# Function to install or update Tales of Maj'Eyal (ToME)
install_tome() {
  echo "Checking for existing ToME installation..."

  # Current version to be installed
  new_version="1.7.6"
  current_version=$(tome --version 2>/dev/null | awk '{print $NF}')

  if [ "$current_version" == "$new_version" ]; then
    echo "ToME $new_version is already installed. No update needed."
  else
    echo "Installing or updating ToME to version $new_version..."

    # URL for the download
    url="https://te4.org/dl/t-engine/t-engine4-linux64-1.7.6.tar.bz2"
    sleep 2   # Delay to prevent rate-limiting

    # Try downloading the latest version with additional flags to handle SSL and retries
    wget --no-check-certificate --tries=3 $url -P /tmp

    if [ $? -eq 0 ]; then
      echo "$(date) Unzipping ToME, this could take a while..."
      # Unzip with a progress message
      sudo tar -xjf /tmp/t-engine4-linux64-1.7.6.tar.bz2 -C /opt

      # Overwrite the symlink if it exists
      sudo ln -sf /opt/tome/tome /usr/local/bin/tome
      alias tome='/usr/local/bin/tome'
      echo "$(date) Tales of Maj'Eyal (ToME) installed/updated successfully."
    else
      echo "Error: Failed to download ToME. Please visit the official website for manual installation: https://te4.org/"
    fi
  fi
  
  # Check if /usr/local/bin is in the PATH export in .bashrc
  if ! grep -q 'export PATH=.*:/usr/local/bin.*' ~/.bashrc; then
    echo "Adding /usr/local/bin to PATH in .bashrc..."
    
    # Check if there's already an export PATH line
    if grep -q 'export PATH=' ~/.bashrc; then
      # Update the existing export PATH line
      sed -i '/export PATH=/ s|$|:/usr/local/bin|' ~/.bashrc
    else
      # Add a new export PATH line
      echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
    fi
    
    echo "/usr/local/bin added to PATH. Reloading .bashrc..."
    source ~/.bashrc
  else
    echo "/usr/local/bin is already in the PATH in .bashrc."
  fi
}

# Function to install Cataclysm: Dark Days Ahead
install_cataclysm() {
  echo "Installing Cataclysm: Dark Days Ahead..."
  git clone https://github.com/CleverRaven/Cataclysm-DDA.git /opt/cataclysm-dda
  cd /opt/cataclysm-dda
  make release
  sudo ln -s /opt/cataclysm-dda/cataclysm-tiles /usr/local/bin/cataclysm
}

# Function to install Angband
install_angband() {
  echo "Installing Angband..."
  sudo apt install -y angband
}

# Function to install Infra Arcana
install_infraarcana() {
  echo "Installing Infra Arcana..."

  # Define URL and target directory
  ARCHIVE_URL="https://gitlab.com/martin-tornqvist/ia/-/jobs/artifacts/v22.1.0/download?job=build-linux"
  TARGET_DIR="/opt/ia"
  
  # Create target directory if it doesn't exist
  sudo mkdir -p $TARGET_DIR
  
  # Download the archive
  wget -O /tmp/ia_build_linux.zip $ARCHIVE_URL
  
  # Unzip the archive to the target directory
  sudo unzip /tmp/ia_build_linux.zip -d $TARGET_DIR
  
  # Navigate to the target directory
  cd $TARGET_DIR
  
  # Find the executable (assuming there's one) and run it
  # Note: Adjust the executable name and path as necessary
  EXECUTABLE=$(find . -name "t-engine" -type f | head -n 1)
  if [[ -f $EXECUTABLE ]]; then
      echo "Starting the application..."
      $EXECUTABLE
  else
      echo "Executable not found. Please check the target directory."
  fi
  
  # Clean up
  rm /tmp/ia_build_linux.zip


  echo "Installing Infra Arcana..."
  wget https://raw.githubusercontent.com/chaosvolt/infraarcana/master/linux/infraarcana-linux.zip -P /tmp
  unzip /tmp/infraarcana-linux.zip -d /opt
  sudo ln -s /opt/infraarcana-linux/infraarcana /usr/local/bin/infraarcana
}

# Function to install Nethack
install_nethack() {
  echo "Installing Nethack..."
  sudo apt install -y nethack-console
}

# Function to install Dungeonmans
install_dungeonmans() {
  echo "Please install 'Dungeonmans' manually from the official website: https://www.dungeonmans.com/"
}

# Function to install The Binding of Isaac: Rebirth
install_bindingofisaac() {
  echo "Please install 'The Binding of Isaac: Rebirth' via Steam."
}

# Function to install Slasher's Keep
install_slasherkeep() {
  echo "Please install 'Slasher's Keep' via Steam."
}

# Function to install UnNetHack
install_unnetHack() {
  echo "Installing UnNetHack..."
  git clone https://github.com/unnethack/unnethack.git /opt/unnethack
  cd /opt/unnethack
  make
  sudo ln -s /opt/unnethack/unnethack /usr/local/bin/unnethack
}

# Function to install Rogue
install_rogue() {
  echo "Installing Rogue..."
  git clone https://github.com/rogue/rogue.git /opt/rogue
  cd /opt/rogue
  make
  sudo ln -s /opt/rogue/rogue /usr/local/bin/rogue
}

# Function to install Dwarf Fortress
install_dwarffortress() {
  echo "Please install latest 'Dwarf Fortress' from the official website: https://www.bay12games.com/dwarves/"
  
  # Define directories and target directory
  DF_URL="https://www.bay12games.com/dwarves/df_50_14_linux.tar.bz2"
  TARGET_DIR="/opt/dwarffortress"
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  
  # Create target directory if it doesn't exist
  sudo mkdir -p $TARGET_DIR
  
  # Change ownership of the target directory to the current user
  sudo chown -R $SUDO_USER:$SUDO_USER $TARGET_DIR
  
  # Download the archive
  wget -O /tmp/dwarffortress.tar.bz2 $DF_URL
  
  # Unzip the archive to the target directory
  tar -xjf /tmp/dwarffortress.tar.bz2 -C $TARGET_DIR
  
  # Change ownership of the extracted files to the current user
  sudo chown -R $SUDO_USER:$SUDO_USER $TARGET_DIR
  
  # Create save and mods directories with correct permissions
  mkdir -p $TARGET_DIR/df_linux/data/save
  mkdir -p $TARGET_DIR/df_linux/data/save/current
  mkdir -p $TARGET_DIR/df_linux/data/mods
  
  # Install necessary libraries
  sudo apt-get update
  sudo apt-get install -y libsdl2-image-2.0-0 libgl1-mesa-glx
  
  # Inform the user how to run Dwarf Fortress
  echo "Dwarf Fortress has been installed. You can run it by typing the following command in your terminal:"
  echo "$TARGET_DIR/df_linux/run_df"
  
  # Clean up
  rm /tmp/dwarffortress.tar.bz2

}

# Function to install Zangband
install_zangband() {
  echo "Installing Zangband..."

  # Install required dependencies for compiling (Debian/Ubuntu-based systems)
  sudo apt-get update
  sudo apt-get install -y build-essential libncurses5-dev git

  # Clone the Zangband repository from GitHub
  git clone https://github.com/ryanfantus/zangband.git /opt/zangband
  cd /opt/zangband

  # Ensure the configure script is executable
  chmod +x configure

  # Run configure to set up the build environment
  ./configure

  # Compile the source code
  make

  # Install the game by creating a symbolic link
  sudo ln -s /opt/zangband/zangband /usr/local/bin/zangband

  echo "Zangband installation complete. You can now run Zangband using the 'zangband' command."

  # Run the installation function
  install_zangband
}


# Function to install Tangledeep
install_tangledeep() {
  echo "Please install 'Tangledeep' via Steam."
}

# Function to install Caves of Qud
install_cavesofqud() {
  echo "Please install 'Caves of Qud' from the official website: https://www.cavesofqud.com/"
}

# Main script execution
display_game_list
install_selected_games

