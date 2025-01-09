#!/bin/bash

# Function to install Frotz
install_frotz() {
  echo "Installing Frotz (Z-machine interpreter)..."
  sudo apt update
  sudo apt install -y frotz
}

# Function to run Zork
run_zork() {
  local script_dir
  script_dir=$(dirname "$(realpath "$0")")
  local zork_file="$script_dir/zork1.z5"

  if [[ -f "$zork_file" ]]; then
    echo "Found zork1.z5 in $script_dir. Running the game..."
    frotz "$zork_file"
  else
    echo "Error: zork1.z5 not found in $script_dir."
    echo "Please ensure zork1.z5 is in the same directory as this script."
    exit 1
  fi
}

# Main script execution
install_frotz
run_zork



#  declare -A zork_urls=(
#    ["zork1"]="http://infocom-if.org/downloads/zork1.zip"
#    ["zork2"]="http://infocom-if.org/downloads/zork2.zip"
#    ["zork3"]="http://infocom-if.org/downloads/zork3.zip"
#  )
#
#  for zork in "${!zork_urls[@]}"; do
#    local url="${zork_urls[$zork]}"
#    local zip_file="$base_dir/${zork}.zip"
#    local extract_dir="$base_dir/${zork}"
#
#    echo "Downloading $zork..."
#    wget --header="User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36" -O "$zip_file" "$url"
#    if [ $? -ne 0 ] || [ ! -s "$zip_file" ]; then
#      echo "Failed to download $zork from $url. Skipping."
#      rm -f "$zip_file"
#      continue
#    fi
