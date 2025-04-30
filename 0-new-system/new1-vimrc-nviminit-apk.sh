#!/bin/bash

# Check and update ~/.vimrc and ~/.config/nvim/init.vim line by line
# Only add a line if it is not currently present.
# Adds bindings to both Vim and Neovim (nvim)
# Designed to be run by the user whose configuration is being modified in Alpine Linux.

echo "Starting Vim/Neovim configuration update..."

# --- Package Installation (using apk for Alpine Linux) ---

# Ensure apk repositories are updated
echo "Updating apk repositories..."
apk update

# Ensure vim is installed
if ! command -v vim &> /dev/null; then
    echo "Vim is not installed. Installing vim..."
    apk add --no-cache vim
else
    echo "Vim is already installed."
fi

# Ensure neovim is installed
if ! command -v nvim &> /dev/null; then
    echo "Neovim is not installed. Installing neovim..."
    # Check if neovim is in main repo or testing; might need to enable testing repo if not found
    # For standard alpine, 'nvim' should be in the main repository
    apk add --no-cache neovim
else
    echo "Neovim is already installed."
fi

# Ensure the nvim config directory and file exist using the user's home directory
echo "Ensuring Neovim configuration directory exists..."
mkdir -p "$HOME/.config/nvim"
nvim_init_file="$HOME/.config/nvim/init.vim"
if [ ! -f "$nvim_init_file" ]; then
    touch "$nvim_init_file"
    echo "Created new $nvim_init_file."
fi

# --- Vim settings and key mappings to apply ---
# (Your existing settings block)
vimrc_block="\" --- Enhanced Vim settings (vim and neovim) ---
\" Set tab behavior to use spaces instead of tabs
set expandtab         \" Use spaces instead of tab characters
set tabstop=4         \" Set tab width to 4 spaces
set shiftwidth=4      \" Set indent width to 4 spaces
set softtabstop=4     \" Set the number of spaces a tab character represents in insert mode
syntax on             \" Syntax highlighting
colorscheme desert    \" Syntax highlighting scheme
\" Available themes: blue, darkblue, default, delek, desert, elflord, evening, habamax, industry, koehler
\" lunapeche lunaperche, morning, murphy, pablo, peachpuff, quiet, ron, shine, slate, torte, zellner
\" Disable tabs (to get a tab, Ctrl-V<Tab>), tab stops are 4 chars, indents are 4 chars
set nonumber                  \" No line numbers (toggle on/off with Ctrl-L or F2 as below)
nnoremap <C-L> :set invnumber<CR>    \" Toggle line numbers on/off
nnoremap <F2> :set invnumber<CR>     \" Toggle line numbers on/off
nnoremap <F4> :set list! listchars=tab:→\\ ,trail:·,eol:¶<CR>  \" F4 shows hidden characters
inoremap <C-s> <Esc>:w<CR>           \" Save file while in insert mode
\" Perform :w write on a protected file even when not as sudo
cnoremap w!! execute 'silent! write !sudo tee % >/dev/null' <bar> edit

set background=dark  \" Dark background
set noerrorbells     \" Disable error bells
set novisualbell     \" Disable error screen flash
set t_vb=            \" Disable all bells
if has('termguicolors')    \" Cursor types
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
\"     Replaces word jump function, but this is redundant as Ctrl+Right/Left already does
\" Shift+Up/Down     => Visual line-wise, select current and one more line
\"     Replaces half-page-up/down function, but redundant as just use PgUp/PgDn
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
\" Disable mouse support if it's causing issues in your terminal/container
set mouse=
"

# Function to update a target configuration file by adding missing lines
update_config_file() {
    local target_file="$1"
    local config_block="$2"
    echo "Updating $target_file..."

    # Create a temporary file to build the new content
    local temp_file=$(mktemp)

    # Read existing content into the temp file initially
    if [ -f "$target_file" ]; then
        cat "$target_file" > "$temp_file"
    fi

    # Iterate over each line in the config_block
    while IFS= read -r line; do
        # Add the line only if it doesn't already exist in the original target file
        # Use grep -Fxq for fixed string, exact line match, quiet output
        if ! grep -Fxq "$line" "$target_file"; then
             # Add the line to the temporary file
             echo "$line" >> "$temp_file"
             echo "  Added: $line" # Optional: show what was added
        fi
    done <<< "$config_block"

    # Remove any completely blank lines added at the very end from the block processing
    # Use tac, sed to remove trailing blank lines, then tac again
    tac "$temp_file" | sed '/^[[:space:]]*$/d; q' | tac > "${temp_file}.cleaned" && mv "${temp_file}.cleaned" "$temp_file"

    # Replace the original file with the updated content from the temporary file
    # Since we are working in the user's home directory, no sudo is needed.
    mv "$temp_file" "$target_file"

    echo "Finished processing $target_file."
}

# --- Apply settings to user configuration files ---

# Update the user's vimrc located in their home directory
vimrc_file="$HOME/.vimrc"
echo "Processing $vimrc_file..."
# The update_config_file function will create the file if it doesn't exist
update_config_file "$vimrc_file" "$vimrc_block"

# Update the user's nvim init.vim located in their home directory
# The directory $HOME/.config/nvim was created earlier.
nvim_init_file="$HOME/.config/nvim/init.vim"
echo "Processing $nvim_init_file..."
# Add the common vimrc_block settings
update_config_file "$nvim_init_file" "$vimrc_block"
# Add Neovim-specific settings
update_config_file "$nvim_init_file" "$nvim_block"


echo -e "\nConfiguration update complete! Reopen vi/vim/nvim to see the updates."
