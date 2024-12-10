#!/bin/bash

echo "Starting enhanced setup for vi/vim configuration..."

# Ensure vim is installed
if ! command -v vim &> /dev/null; then
  echo "Vim is not installed. Installing vim..."
  sudo apt update && sudo apt install -y vim
else
  echo "Vim is already installed."
fi

# Determine which vimrc file to update
if [ "$(id -u)" -eq 0 ]; then
  # Running as root, update global vimrc
  TARGET_VIMRC="/etc/vim/vimrc"
  echo "Running as root. Updating global configuration: $TARGET_VIMRC"
else
  # Running as normal user, update user-specific .vimrc
  TARGET_VIMRC="$HOME/.vimrc"
  echo "Running as a normal user. Updating user configuration: $TARGET_VIMRC"
  
  # Ensure the .vimrc file exists for the user
  if [ ! -f "$TARGET_VIMRC" ]; then
    touch "$TARGET_VIMRC"
    echo "Created new $TARGET_VIMRC."
  fi
fi

# Function to check if a configuration line exists in a file
check_and_add() {
  local file=$1
  local regex=$2
  local line=$3
  local comment=$4
  local global_check=${5:-false}  # Flag to check global vimrc if not root

  # If not root and global check is enabled, look for the line in global vimrc
  if [ "$global_check" = true ] && [ -f "/etc/vim/vimrc" ]; then
    if grep -qE "$regex" "/etc/vim/vimrc"; then
      echo "The setting \"$line\" is already present in /etc/vim/vimrc. Skipping."
      return
    fi
  fi

  # Check and add to the target file
  if ! grep -qE "$regex" "$file"; then
    echo "Adding \"$line  $comment\" to $file"
    echo "$line  $comment" >> "$file"
  else
    echo "The setting \"$line\" is already present in $file. Skipping."
  fi
}

# Settings to apply with comments
settings=(
  "^syntax on:syntax on:\" Enable syntax highlighting"
  "^set number:set number:\" Show line numbers"
  "^set background=dark:set background=dark:\" Adjust color scheme for dark backgrounds"
  "^colorscheme .*:colorscheme desert:\" Set the color scheme to 'desert'"
  "^set noerrorbells:set noerrorbells:\" Disable audible error bells"
  "^set novisualbell:set novisualbell:\" Disable visual error bells"
  "^set t_vb=:set t_vb=:\" Disable terminal beep"
  "^map <C-a> <esc>gg0VG<CR>:map <C-a> <esc>gg0VG<CR>:\" Map Ctrl+A to select all in normal mode"
)

# Themes comment
themes_comment="\" Available themes:
\" blue, darkblue, default, delek, desert, elflord, evening, habamax, industry,
\" koehler, lunaperche, morning, murphy, pablo, peachpuff, quiet, ron, shine,
\" slate, torte, zellner"

# Apply settings
for setting in "${settings[@]}"; do
  IFS=":" read -r regex line comment <<< "$setting"

  # For non-root users, check globally before adding to user-specific vimrc
  global_check=false
  if [ "$(id -u)" -ne 0 ]; then
    global_check=true
  fi

  check_and_add "$TARGET_VIMRC" "$regex" "$line" "$comment" "$global_check"
done

# Add themes comment if not already present
if ! grep -qE "^\" Available themes" "$TARGET_VIMRC"; then
  echo "Adding themes comment to $TARGET_VIMRC."
  echo -e "\n$themes_comment" >> "$TARGET_VIMRC"
else
  echo "Themes comment already present in $TARGET_VIMRC. Skipping."
fi

echo -e "\nConfiguration complete! Reopen vi/vim to see the updates."

