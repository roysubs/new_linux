#!/bin/bash

# Check and update ~/.vimrc and ~/.config/nvim/init.vim line by line
# Only add a line if it is not currently present.
# Adds bindings to to both Vim and Neovim (nvim)

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

vimrc_block="\" --- Enhanced Vim settings (vim and neovim) ---
\" Set tab behavior to use spaces instead of tabs
set expandtab        \" Use spaces instead of tab characters
set tabstop=4        \" Set tab width to 4 spaces
set shiftwidth=4     \" Set indent width to 4 spaces
set softtabstop=4    \" Set the number of spaces a tab character represents in insert mode
syntax on            \" Syntax highlighting
colorscheme desert   \" Syntax highlighting scheme
\" Available themes: blue, darkblue, default, delek, desert, elflord, evening, habamax, industry, koehler
\" lunapeche lunaperche, morning, murphy, pablo, peachpuff, quiet, ron, shine, slate, torte, zellner
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

\" --- Visual Mode Enhancements ---
\" <C-v> is generally unavailable when connected by a terminal emulator so <C-q> was
\" also added as a core vim default due to common terminals using <C-v> but neither
\" are ideal to use. To provide options similar to Notepad++ and VS Code can make it
\" easier / more intuitive when switching between editors, but multi-key selections
\" in Vim are complex (require plugins), so we will map as follows:
\"
\" Shift+Right/Left => Visual character-wise, select the word under the cursor
\"   Replaces word jump function, but this is redundant as Ctrl+Right/Left already does
\" Shift+Up/Down    => Visual line-wise, select current and one more line
\"   Replaces half-page-up/down function, but redundant as just use PgUp/PgDn
\" Alt+Up/Down/Left/Right  => Visual block-wise, select rectangle as move around.
\" Avoiding Ctrl+Left/Right, leaving those as default navigate word actions.
\" 
\" This setup works well with tmux (but not byobu, so avoid byobu).
\" Note: The default keys 'v' (Visual Character-wise) and 'V' (Visual Line-wise)
\" still work as usual and are not affected by these mappings.
\" Also add 'vb' as a key entry to go with 'v' and 'V'
nnoremap vb <C-q>  \" vb -> Enter block-wise visual mode (equivalent to 'Ctrl-v' / 'Ctrl-q')
\" So, v (VISUAL), V (VISUAL LINE), vb (VISUAL BLOCK)

\" --- Map Shift+Right and Shift+Left for Visual Word Selection ---
\" These mappings will override the default word-jumping behaviour (W and B for Normal mode) as that already
\" exists with Ctrl+Right/Left.
\" The original W and B jumps are still available directly in Normal mode.
\" Shift+Right: Select word under/after cursor
\" In Normal mode: Enter visual mode (v), move one word forward (w). Selects from cursor to start of next word.
nmap <S-Right> vw
\" In Insert mode: Exit Insert mode (<Esc>), then do the Normal mode action (vw).
imap <S-Right> <Esc>vw
\" Shift+Left: Select word under/before cursor
\" In Normal mode: Jump back one word (b), enter visual mode (v), select inner word (iw).
\" Selects the word you just jumped back into/past.
nmap <S-Left> bviw
\" In Insert mode: Exit Insert mode (<Esc>), then do the Normal mode action (bviw).
imap <S-Left> <Esc>bviw
\" In Visual mode (vmap): Do NOT remap <S-Right> and <S-Left>.
\" Their default behaviour (extending selection by WORD forwards/backwards) is useful
\" and aligns with extending a word-based selection.

\" --- Map Shift+Home and Shift+End for Visual Line Start/End Selection ---
\" Shift+Home: Visual select from cursor to beginning of line
\" In Normal mode: Enter visual mode (v), move to start of line (0).
nmap <S-Home> v0
\" In Insert mode: Exit Insert mode (<Esc>), then do the Normal mode action (v0).
imap <S-Home> <Esc>v0
\" In Visual mode (vmap): Move to start of line (0). Selection extends automatically.
vmap <S-Home> 0

\" Shift+End: Visual select from cursor to end of line
\" In Normal mode: Enter visual mode (v), move to end of line ($).
nmap <S-End> v$
\" In Insert mode: Exit Insert mode (<Esc>), then do the Normal mode action (v$).
imap <S-End> <Esc>v$
\" In Visual mode (vmap): Move to end of line ($). Selection extends automatically.
vmap <S-End> $

\" --- Map Alt+Up and Alt+Down for Visual Block-wise Selection ---
\" <C-o> drops back to Insert mode after each step, cancelling selection, so use <Esc> to
\" leave Insert mode permanently when starting selection, and vmap for continuous selection.
\" Alt+Up in Insert mode: Exit Insert, Enter Block Visual, Move Up.
\" <Esc>: Exit Insert mode permanently. <C-v>: Enter block-wise Visual mode.
\" k: Move cursor up (extends selection in Visual mode).
inoremap <M-Up> <Esc><C-v>k
\" Alt+Down in Insert mode: Exit Insert, Enter Block Visual, Move Down.
\" <Esc>: Exit Insert mode permanently. <C-v>: Enter block-wise Visual mode.
\" j: Move cursor down (extends selection in Visual mode).
inoremap <M-Down> <Esc><C-v>j
\" Now, handle Alt+Up/Down when already in Normal or Visual mode.
\" If you're already in Normal mode, just go straight to Visual Block and move.
\" If you're already in ANY Visual mode (char, line, or block), just perform the move,
\" which will extend the current selection.
\" Alt+Up in Normal mode: Enter Block Visual, Move Up.
nmap <M-Up> <C-v>k
\" Alt+Down in Normal mode: Enter Block Visual, Move Down.
nmap <M-Down> <C-v>j
\" Alt+Up in Visual mode (any type): Just move Up. Selection extends automatically.
vmap <M-Up> k
\" Alt+Down in Visual mode (any type): Just move Down. Selection extends automatically.
vmap <M-Down> j

\" --- Map Shift+Up and Shift+Down for Visual Line-wise Selection ---
\" Overrides default half-page scrolling behavior for <S-Up>/<S-Down>
\" Shift+Up in Insert mode: Exit Insert, Enter Line Visual, Select Line Above
\" <Esc>: Exit Insert mode permanently.
\" V: Enter Line-wise Visual mode.
\" k: Move cursor up. When in Line Visual mode, this extends the selection to the line above.
inoremap <S-Up> <Esc>Vk
\" Shift+Down in Insert mode: Exit Insert, Enter Line Visual, Select Line Below
\" <Esc>: Exit Insert mode permanently.
\" V: Enter Line-wise Visual mode.
\" j: Move cursor down. When in Line Visual mode, this extends the selection to the line below.
inoremap <S-Down> <Esc>Vj
\" Shift+Up in Normal mode: Enter Line Visual, Select Line Above
\" V: Enter Line-wise Visual mode.
\" k: Move cursor up.
nmap <S-Up> Vk
\" Shift+Down in Normal mode: Enter Line Visual, Select Line Below
\" V: Enter Line-wise Visual mode.
\" j: Move cursor down.
nmap <S-Down> Vj
\" Shift+Up in Visual mode (any type): Move Selection Up by a Line
\" When you are already in Visual mode and press S-Up, just move up.
\" In line-wise visual, this reduces the bottom boundary or extends the top boundary.
vmap <S-Up> k
\" Shift+Down in Visual mode (any type): Move Selection Down by a Line
\" When you are already in Visual mode and press S-Down, just move down.
\" In line-wise visual, this extends the bottom boundary or reduces the top boundary.
vmap <S-Down> j

\" --- TAB Key Enhancements ---
\" In normal mode, a TAB should go into insert mode, insert a tab, then go back to normal mode.
\" This provides a quick way to insert a tab without staying in insert mode.
nnoremap <Tab> i<Tab><Esc>

\" In visual mode, a TAB should indent the selected block using the standard '>' command,
\" and then re-select the same area using 'gv'.
vmap <Tab> >gv

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

