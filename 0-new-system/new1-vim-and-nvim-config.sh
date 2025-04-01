#!/bin/bash

# Check and update ~/.vimrc and ~/.config/nvim/init.vim line by line
# Only add a line if it is not currently present.
# All compatible with both Vim and Neovim (nvim)

# If 'root' is passed as the first argument, then only apply the settings to /etc/vim/vimrc
if [[ "$1" == "root" ]]; then
  # Ensure the script is running as root or via sudo
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: This script must be run as root to apply global settings."
    exit 1
  fi
  echo "Running with 'root' option. Changes will be applied to both global and user vimrc files."
  APPLY_GLOBAL=true
else
  APPLY_GLOBAL=false
fi

# Identify the normal user's home directory, even if running as sudo
NORMAL_USER=${SUDO_USER:-$USER}
NORMAL_USER_HOME=$(getent passwd "$NORMAL_USER" | cut -d: -f6)

# Ensure vim is installed
if ! command -v vim &> /dev/null; then
  echo "Vim is not installed. Installing vim..."
  sudo apt update && sudo apt install -y vim
else
  echo "Vim is already installed."
fi

# Ensure neovim is installed
if ! command -v nvim &> /dev/null; then
  echo "Neovim is not installed. Installing neovim..."
  sudo apt update && sudo apt install -y neovim
else
  echo "Neovim is already installed."
fi
[ -f ~/.config/nvim/init.vim ] || mkdir -p ~/.config/nvim && touch ~/.config/nvim/init.vim

# Vim settings and key mappings to apply
vimrc_block="\" General Vim settings
syntax on          \" Syntax highlighting
colorscheme desert \" Syntax highlighting scheme
\" Available themes:
\" blue, darkblue, default, delek, desert, elflord, evening, habamax, industry,
\" koehler, lunaperche, morning, murphy, pablo, peachpuff, quiet, ron, shine,
\" slate, torte, zellner
\" Disable tabs (to get a tab, Ctrl-V<Tab>), tab stops are 4 chars, indents are 4 chars
set nonumber                          \" No line numbers (toggle on/off with Ctrl-L or F2 as below)
nnoremap <C-L> :set invnumber<CR>     \" Toggle line numbers on/off
nnoremap <F2> :set invnumber<CR>      \" Toggle line numbers on/off
nnoremap <F4> :set list! listchars=tab:→\\ ,trail:·,eol:¶<CR>  \" F4 shows hidden characters
inoremap <C-s> <Esc>:w<CR>            \" Save file while in insert mode
\" Perform :w write on a protected file even when not as sudo
cnoremap w!! execute 'silent! write !sudo tee % >/dev/null' <bar> edit

set background=dark  \" Dark background
set noerrorbells     \" Disable error bells
set novisualbell     \" Disable error screen flash
set t_vb=            \" Disable all bells
if has('termguicolors')   \" Cursor types
    let &t_SI = \"\\e[6 q\"
    let &t_SR = \"\\e[4 q\"
    let &t_EI = \"\\e[2 q\"
endif

\" Shift-Up/Down / Ctrl-Up/Down for Visual Line Selection
nnoremap <S-Down> Vj       \" Shift-Down : Select one line down
nnoremap <S-Up> Vk         \" Shift-Up   : Select one line up
inoremap <S-Down> <Esc>Vj  \" Visual Line Select also from insert mode
inoremap <S-Up> <Esc>Vk    \" Visual Line Select also from insert mode
nnoremap <C-Down> <C-V>j   \" Ctrl-Down  : Block selection down
nnoremap <C-Up> <C-V>k     \" Ctrl-Up    : Block selection up
\" Alt-Left/Right for block selection sideways
\" Do not use Ctrl-Left/Right as that is default navigate word action
nnoremap <M-Right> <C-V>l  \" Alt-Right : Block select right
nnoremap <M-Left> <C-V>h   \" Alt-Left  : Block select left
nnoremap vv v      \" vv -> Enter character-wise visual mode (default 'v')
nnoremap vV V      \" vV -> Enter line-wise visual mode (equivalent to 'V')
nnoremap vb <C-V>  \" vb -> Enter block-wise visual mode (equivalent to 'Ctrl-V')

"

# Neovim-specific settings block
nvim_block="
\" Neovim-specific settings
set mouse=
"

update_vimrc() {
  local target_vimrc="$1"
  local source_vim_block="$2"
  echo "Updating $target_vimrc with $source_vim_block..."
  
  # Ensure the target file exists
  if [ ! -f "$target_vimrc" ]; then
    touch "$target_vimrc"
    echo "Created new $target_vimrc."
  fi

  # Iterate over each line in vimrc_block
  while IFS= read -r line; do
    # Handle empty or whitespace-only lines
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]]; then
      echo "" >> "$target_vimrc"
    # # Handle lines starting with a comment character
    # elif [[ "$line" =~ ^\" ]]; then
    #   echo "$line" >> "$target_vimrc"

    # Add the line only if it doesn't already exist
    # grep -Fxq:
    # -F: Match fixed strings (no regex interpretation).
    # -x: Match the whole line exactly.
    # -q: Suppress output, suitable for checks.
    elif ! grep -Fxq "$line" "$target_vimrc"; then
      echo "$line" >> "$target_vimrc"
    fi
  done <<< "$source_vim_block"

  # Remove trailing blank lines
  sed -i ':a; N; $!ba; s/\n[[:space:]]*\n*$//' "$target_vimrc"
  echo "Finished updating $target_vimrc."
}

if [[ "$APPLY_GLOBAL" == true ]]; then
  update_vimrc "/etc/vim/vimrc"
else
  # Update the normal user's vimrc
  if [ -f "$NORMAL_USER_HOME/.vimrc" ]; then
    update_vimrc "$NORMAL_USER_HOME/.vimrc" "$vimrc_block"
  fi
  if [ -f "$NORMAL_USER_HOME/.config/nvim/init.vim" ]; then
    update_vimrc "$NORMAL_USER_HOME/.config/nvim/init.vim" "$vimrc_block"
  fi
  # Update Neovim-specific settings with extra block
  if [ -f "$NORMAL_USER_HOME/.config/nvim/init.vim" ]; then
    update_vimrc "$NORMAL_USER_HOME/.config/nvim/init.vim" "$nvim_block"
  fi

fi

echo -e "\nConfiguration complete! Reopen vi/vim to see the updates."

