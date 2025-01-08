#!/bin/bash

install_frotz_and_zork() {
  echo "Installing Frotz (Z-machine interpreter)..."
  sudo apt update
  sudo apt install -y frotz unzip wget

  echo "Setting up Zork games..."
  local base_dir="$HOME/infocom"
  mkdir -p "$base_dir"

  # Use a source that provides Z-machine compatible files
  declare -A zork_urls=(
    ["zork1"]="https://https://content.instructables.com/FZ4/2VPP/H144OTCW/FZ42VPPH144OTCW.z5"
    ["zork2"]="https://ifarchive.org/if-archive/games/zcode/Zork2.z5"
    ["zork3"]="https://ifarchive.org/if-archive/games/zcode/Zork3.z5"
  )

  for zork in "${!zork_urls[@]}"; do
    local url="${zork_urls[$zork]}"
    local game_file="$base_dir/${zork}.z5"

    echo "Downloading $zork from $url..."
    wget --header="User-Agent: Mozilla/5.0 (X11; Linux x86_64)" -O "$game_file" "$url"
    if [ $? -ne 0 ] || [ ! -s "$game_file" ]; then
      echo "Failed to download $zork from $url. Skipping."
      rm -f "$game_file"
      continue
    fi

    echo "Creating symbolic link for $zork..."
    local link_path="/usr/local/bin/$zork"
    echo "#!/bin/bash" | sudo tee "$link_path" > /dev/null
    echo "frotz \"$game_file\"" | sudo tee -a "$link_path" > /dev/null
    sudo chmod +x "$link_path"
    echo "You can now run the game with: $zork"
  done
}

install_frotz_and_zork

