#!/bin/bash

# Script to install a selection of popular console-based games

# Function to display the game list with details
display_game_list() {
  echo "Available console-based games to install:"
  echo "-------------------------------------------------------------"

  games=(
    "Nethack"
    "Angband"
    "Brogue"
    "Rogue"
    "Cataclysm: Dark Days Ahead"
    "Dungeon Crawl Stone Soup"
    "The Battle for Wesnoth"
    "Frotz (Z-machine interpreter)"
    "Console Tetris"
    "Larn"
    "Nudoku"
    "Puyopuyo Tsu (console version)"
  )

  details=(
    # Game details: name, size, source, url
    "A classic roguelike dungeon crawler.\n   Size: ~20MB\n   Maintained, GitHub repository.\n   Source: https://github.com/NetHack/NetHack\n   URL: https://www.nethack.org/"
    "A classic dungeon crawler with deep exploration.\n   Size: ~5MB\n   Maintained, GitHub repository.\n   Source: https://github.com/angband/angband\n   URL: https://angband.github.io/"
    "A roguelike with a minimalist design and a strong focus on exploration.\n   Size: ~5MB\n   Maintained, GitHub repository.\n   Source: https://github.com/mysticman/brogue\n   URL: https://brogue.github.io/"
    "The original roguelike game that started the genre.\n   Size: ~1MB\n   Maintained, GitHub repository.\n   Source: https://github.com/rogue/rogue\n   URL: https://github.com/rogue/rogue"
    "A post-apocalyptic survival roguelike.\n   Size: ~200MB\n   Maintained, GitHub repository.\n   Source: https://github.com/CleverRaven/Cataclysm-DDA\n   URL: https://cataclysmdda.org/"
    "A popular and highly detailed roguelike dungeon crawl.\n   Size: ~10MB\n   Maintained, GitHub repository.\n   Source: https://github.com/crawl/crawl\n   URL: https://www.dcss.eu/"
    "A strategy-focused, turn-based game with a fantasy setting.\n   Size: ~100MB\n   Maintained, GitHub repository.\n   Source: https://github.com/wesnoth/wesnoth\n   URL: https://wesnoth.org/"
    "A classic text-based interpreter for Z-machine games (Infocom-style). Install and play interactive fiction.\n   Size: ~1MB\n   Maintained, GitHub repository.\n   Source: https://github.com/DavidGriffith/frotz\n   URL: https://frotz.github.io/"
    "A simple implementation of Tetris for the terminal.\n   Size: ~1MB\n   Maintained, GitHub repository.\n   Source: https://github.com/robobobo/tetris\n   URL: https://robobobo.github.io/tetris/"
    "A classic roguelike dungeon game.\n   Size: ~2MB\n   Maintained, GitHub repository.\n   Source: https://github.com/stevew/larn\n   URL: https://larn.org/"
    "A console-based Sudoku game with a simple interface.\n   Size: ~1MB\n   Maintained, GitHub repository.\n   Source: https://github.com/joeyh/nudoku\n   URL: https://joeyh.name/code/nudoku/"
    "A puzzle game inspired by Puyopuyo, implemented in a console version.\n   Size: ~5MB\n   Maintained, GitHub repository.\n   Source: https://github.com/riusksk/puyopuyo\n   URL: https://github.com/riusksk/puyopuyo"
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
        1) install_nethack ;;
        2) install_angband ;;
        3) install_brogue ;;
        4) install_rogue ;;
        5) install_cataclysm ;;
        6) install_dcss ;;
        7) install_wesnoth ;;
        8) install_frotz ;;
        9) install_tetris ;;
        10) install_larn ;;
        11) install_nudoku ;;
        12) install_puyopuyo ;;
        *) echo "Invalid number: $num" ;;
      esac
    done
  fi
}

# Install all games
install_all_games() {
  install_nethack
  install_angband
  install_brogue
  install_rogue
  install_cataclysm
  install_dcss
  install_wesnoth
  install_frotz
  install_tetris
  install_larn
  install_nudoku
  install_puyopuyo
}

# Install Nethack
install_nethack() {
  echo "Installing Nethack..."
  sudo apt install -y nethack-console
}

# Install Angband
install_angband() {
  echo "Installing Angband..."
  sudo apt install -y angband
}

# Install Brogue
install_brogue() {
  echo "Installing Brogue..."
  git clone https://github.com/mysticman/brogue.git /opt/brogue
  cd /opt/brogue
  make
  sudo ln -s /opt/brogue/brogue /usr/local/bin/brogue
}

# Install Rogue
install_rogue() {
  echo "Installing Rogue..."
  git clone https://github.com/rogue/rogue.git /opt/rogue
  cd /opt/rogue
  make
  sudo ln -s /opt/rogue/rogue /usr/local/bin/rogue
}

# Install Cataclysm: Dark Days Ahead
install_cataclysm() {
  echo "Installing Cataclysm: Dark Days Ahead..."
  git clone https://github.com/CleverRaven/Cataclysm-DDA.git /opt/cataclysm-dda
  cd /opt/cataclysm-dda
  make release
  sudo ln -s /opt/cataclysm-dda/cataclysm-tiles /usr/local/bin/cataclysm
}

# Install Dungeon Crawl Stone Soup
install_dcss() {
  echo "Installing Dungeon Crawl Stone Soup (DCSS)..."
  sudo apt install -y crawl
}

# Install Wesnoth
install_wesnoth() {
  echo "Installing The Battle for Wesnoth..."
  sudo apt install -y wesnoth
}

# Install Frotz (Z-machine interpreter)
install_frotz() {
  echo "Installing Frotz (Z-machine interpreter)..."
  sudo apt install -y frotz
}

# Install Tetris
install_tetris() {
  echo "Installing Tetris..."
  git clone https://github.com/robobobo/tetris.git /opt/tetris
  cd /opt/tetris
  make
  sudo ln -s /opt/tetris/tetris /usr/local/bin/tetris
}

# Install Larn
install_larn() {
  echo "Installing Larn..."
  git clone https://github.com/stevew/larn.git /opt/larn
  cd /opt/larn
  make
  sudo ln -s /opt/larn/larn /usr/local/bin/larn
}

# Install Nudoku
install_nudoku() {
  echo "Installing Nudoku..."
  sudo apt install -y nudoku
}

# Install Puyopuyo
install_puyopuyo() {
  echo "Installing Puyopuyo..."
  git clone https://github.com/riusksk/puyopuyo.git /opt/puyopuyo
  cd /opt/puyopuyo
  make
  sudo ln -s /opt/puyopuyo/puyopuyo /usr/local/bin/puyopuyo
}

# Main
display_game_list
install_selected_games

