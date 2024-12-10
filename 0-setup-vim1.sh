#!/bin/bash

echo "Starting enhanced setup for vi/vim configuration..."

# Ensure vim is installed
if ! command -v vim &> /dev/null; then
  echo "Vim is not installed. Installing vim..."
  sudo apt update && sudo apt install -y vim
else
  echo "Vim is already installed."
fi

# Function to check if a configuration line exists in a file
check_and_add() {
  local file=$1
  local regex=$2
  local line=$3

  if ! grep -qE "$regex" "$file"; then
    echo "Adding \"$line\" to $file"
    echo "$line" >> "$file"
  else
    echo "The setting \"$line\" is already present in $file. Skipping."
  fi
}

# Global vimrc file
GLOBAL_VIMRC="/etc/vim/vimrc"

# User-specific .vimrc file
USER_VIMRC="$HOME/.vimrc"

# Ensure .vimrc exists for the user
if [ ! -f "$USER_VIMRC" ]; then
  touch "$USER_VIMRC"
  echo "Created new $USER_VIMRC."
fi

# Settings to apply
settings=(
  "^syntax on:syntax on"
  "^set number:set number"
  "^set background=dark:set background=dark"
  "^colorscheme .*:colorscheme desert"
  "^set noerrorbells:set noerrorbells"
  "^set novisualbell:set novisualbell"
  "^set t_vb=:set t_vb="
  "^map <C-a> <esc>gg0VG<CR>:map <C-a> <esc>gg0VG<CR>"
)
# noerrorbells: Disables the error bells for invalid operations (e.g., hitting Page Up on the first line).
# novisualbell: Disables the screen flash (visual bell) when the audible bell is disabled.
# t_vb=: Ensures Vim doesn't attempt any kind of bell signal.
#!/bin/bash

themes_comment="\" Available themes:
\" blue, darkblue, default, delek, desert, elflord, evening, habamax, industry,
\" koehler, lunaperche, morning, murphy, pablo, peachpuff, quiet, ron, shine,
\" slate, torte, zellner"

# Apply settings to vimrc files
for setting in "${settings[@]}"; do
  IFS=":" read -r regex line <<< "$setting"

  # Check global vimrc first
  if [ -f "$GLOBAL_VIMRC" ]; then
    check_and_add "$GLOBAL_VIMRC" "$regex" "$line"
  else
    echo "$GLOBAL_VIMRC not found. Skipping global configuration for \"$line\"."
  fi

  # Always ensure user vimrc has the setting if not present globally
  check_and_add "$USER_VIMRC" "$regex" "$line"
done

# Add themes comment to user vimrc if not already present
if ! grep -qE "^\" Available themes" "$USER_VIMRC"; then
  echo "Adding themes comment to $USER_VIMRC."
  echo -e "\n$themes_comment" >> "$USER_VIMRC"
else
  echo "Themes comment already present in $USER_VIMRC. Skipping."
fi

echo -e "\nConfiguration complete! Reopen vi/vim to see the updates."

