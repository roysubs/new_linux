#!/bin/bash

install_frotz_and_zork() {
  echo "Installing Frotz (Z-machine interpreter)..."
  sudo apt update
  sudo apt install -y frotz unzip

  echo "Setting up Zork games..."
  local base_dir="$HOME/infocom"
  mkdir -p "$base_dir"

  declare -A zork_urls=(
    ["zork1"]="http://infocom-if.org/downloads/zork1.zip"
    ["zork2"]="http://infocom-if.org/downloads/zork2.zip"
    ["zork3"]="http://infocom-if.org/downloads/zork3.zip"
  )

  for zork in "${!zork_urls[@]}"; do
    local url="${zork_urls[$zork]}"
    local zip_file="$base_dir/${zork}.zip"
    local extract_dir="$base_dir/${zork}"

    echo "Downloading $zork..."
    wget --header="User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36" -O "$zip_file" "$url"
    if [ $? -ne 0 ] || [ ! -s "$zip_file" ]; then
      echo "Failed to download $zork from $url. Skipping."
      rm -f "$zip_file"
      continue
    fi

    echo "Extracting $zork to $extract_dir..."
    mkdir -p "$extract_dir"
    unzip -q "$zip_file" -d "$extract_dir"
    rm -f "$zip_file"

    echo "Creating symbolic link for $zork..."
    local game_file
    game_file=$(find "$extract_dir" -type f -name "*.z*" | head -n 1)
    if [ -n "$game_file" ]; then
      local link_path="/usr/local/bin/$zork"
      sudo ln -sf "$(which frotz) \"$game_file\"" "$link_path"
      sudo chmod +x "$link_path"
      echo "You can now run the game with: $zork"
    else
      echo "Failed to find game file for $zork in $extract_dir."
    fi
  done
}

install_frotz_and_zork

