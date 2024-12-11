#!/bin/bash

# Go through settings in vimrc_block line by line and update .vimrc
# with the settings if they do not already exist

echo "Starting setup for vimrc configuration..."

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

# Vim settings and key mappings to apply with comments
vimrc_block="\" General Vim settings
syntax on            \" Enable syntax highlighting
set number           \" Show line numbers
set expandtab tabstop=4 shiftwidth=4   \" Disable tabs, pressing tab creates 4 char
set background=dark  \" Adjust color scheme for dark backgrounds
set noerrorbells     \" Disable audible error bells
set novisualbell     \" Disable visual error bells
set t_vb=            \" Disable terminal beep
colorscheme desert   \" Set the color scheme to 'desert'
\" Available themes:
\" blue, darkblue, default, delek, desert, elflord, evening, habamax, industry,
\" koehler, lunaperche, morning, murphy, pablo, peachpuff, quiet, ron, shine,
\" slate, torte, zellner
\" Disable tabs (to get a tab, Ctrl-V<Tab>), tab stops are 4 chars, indents are 4 chars
if has('termguicolors')
    \" Change cursor shape for different modes
    let &t_SI = \"\\e[6 q\"   \" Insert mode: Blinking bar
    let &t_SR = \"\\e[4 q\"   \" Replace mode: Steady underline
    let &t_EI = \"\\e[2 q\"   \" Normal mode: Steady block
endif

\" Key mappings, e.g., nnoremap: n (normal mode) nonre (non-recursive), map (map key)
nnoremap <C-L> :set invnumber<CR>   \" Toggle line numbers on/off with Ctrl+L
nnoremap <F2> :set invnumber<CR>    \" Toggle line numbers on/off with F2
nnoremap <F4> :set list! listchars=tab:→\ ,trail:·,eol:¶<CR>  \" Toggle non-print listchars with F4
\" map <C-a> <esc>gg0VG<CR>         \" Map Ctrl+A to select all in normal mode
nnoremap <C-a> <esc>gg0VG<CR>       \" Map Ctrl+A to select all in normal mode
inoremap <C-s> <esc>:w<CR>          \" Map Ctrl+S to save in insert mode
\" Visual shortcuts (press once then let go of Ctrl).
\" Ctrl+Up/Down/Left/Right to *start* a Visual Block, then let
\" go of Ctrl and continue with cursor keys to setup a block.
\" d (delete), y (yank), I (Visual Block insert and replace)
\" Shift+Down ir Shift+Up for Visual Line mode.
nnoremap <S-Down> <Esc>Vj
\" Map Shift + Up to Visual Line mode and move the cursor up
nnoremap <S-Up> <Esc>Vk
\" Map Ctrl+Down to Visual Block Mode and move the cursor down
nnoremap <C-Down> <Esc><C-V>j
\" Map Ctrl+Up to Visual Block Mode and move the cursor up
nnoremap <C-Up> <Esc><C-V>k
\" Map Ctrl+Right to Visual Block Mode and move the cursor right
nnoremap <C-Right> <Esc><C-V>l
\" Map Ctrl+Left to Visual Block Mode and move the cursor left
nnoremap <C-Left> <Esc><C-V>h

\" Allow saving of files as sudo if did not start vim with sudo
cnoremap w!! execute 'silent! write !sudo tee % >/dev/null' <bar> edit

\" Jump between windows with Ctrl-h/j/k/l
\" nnoremap <C-H> <C-W>h
\" nnoremap <C-J> <C-W>j
\" nnoremap <C-K> <C-W>k
\" nnoremap <C-L> <C-W>l

"

# Iterate over each line in vimrc_block
while IFS= read -r line; do
  # If the line is blank or contains only spaces/tabs, add a real blank line
  if [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]]; then
    echo "" >> "$TARGET_VIMRC"

  # If the line starts with a comment (lines starting with `"`), directly add it
  elif [[ "$line" =~ ^\" ]]; then
    echo "$line" >> "$TARGET_VIMRC"

  # For all other lines, check if it exists in the vimrc and add it if not
  # grep -F interprets as literal strings, ignore all special regex metacharacters.
  # This will prevent errors when there are characters like [ or ] in the line.
  elif ! grep -F -q "^$line" "$TARGET_VIMRC"; then
    echo "$line" >> "$TARGET_VIMRC"
  fi
done <<< "$vimrc_block"

# Remove any blank lines, but only at the end of vimrc, that may be introduced due the way blank lines are added above.
sed -i ':a; N; $!ba; s/\n[[:space:]]*\n*$//' "$TARGET_VIMRC"
# :a; N; $!ba:             This reads the whole file into memory.
# s/\n[[:space:]]*\n*$//   Removes any empty lines or whitespace-only lines from the end of the file.

echo "Finished updating $TARGET_VIMRC"

echo -e "\nConfiguration complete! Reopen vi/vim to see the updates."


####################
#
# nvim configuration (~/.config/init.vim)
# Copy .vimrc to init.vim only if it does not already exist
#
####################

mkdir -p ~/.config/nvim
cp ~/.vimrc ~/.config/nvim/init.vim
grep -q "^set guicursor=" ~/.config/nvim/init.vim || echo "set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50" >> ~/.config/nvim/init.vim

