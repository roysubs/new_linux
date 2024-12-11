#!/bin/bash

BASHRC_FILE="$HOME/.bashrc"
# Uncomment alias lines for ll, la, and l
echo "Uncommenting alias lines in ~/.bashrc"
sed -i '/^#alias ll=/ s/^#//' "$BASHRC_FILE"
sed -i '/^#alias la=/ s/^#//' "$BASHRC_FILE"
sed -i '/^#alias l=/ s/^#//' "$BASHRC_FILE"
# Notify the user
echo "Alias lines have been uncommented. To apply changes, run:"
echo "source ~/.bashrc"

# viconfig() { [[ \$(command -v vi) == *nvim* ]] && vi ~/.config/nvim/init.vim || vi ~/.vimrc; }  # Open config depending on what vi is aliased to

# Block of text to add
bashrc_block="
# user alias/function/export definitions
export EDITOR=vi
alias vimrc='vi ~/.vimrc'
alias bashrc='vi ~/.bashrc'
alias nvimrc='vi ~/.config/nvim/init.vim'
alias initvim='vi ~/.config/nvim/init.vim'
alias vimrcroot='sudo vi /etc/vim/vimrc'
alias vimrcsudo='sudo vi /etc/vim/vimrc'
alias cd..='cd ..'
alias ..='cd ..'
alias ls.='ls -d .*'
alias ll.='ls -ald .*'
alias apti='sudo apt install'  # apti/ii (install), aptr/rr (remove), aptu/uu (update-upgrade)
alias ii='sudo apt install'
alias aptr='sudo apt remove'
alias rr='sudo apt remove'
alias aptu='sudo apt update; sudo apt upgrade; sudo apt autoremove'   # Quick update / upgrade / autoremove
alias uu='sudo apt update; sudo apt upgrade; sudo apt autoremove'
alias apts='sudo apt search'   # apts/asearch/afind (search for packagename)
alias asearch='sudo apt search'
alias afind='sudo apt search'
alias ainfo='sudo apt info'     # apti/ainfo (info about packagename)
alias hg='history | grep'       # 'history-grep'. After search, !201 will run item 201 in history
alias ifconfig='sudo ifconfig'  # Here because 'ifconfig' shows 'command not found' if run without sudo (apt install net-tools)
alias ipconfig='sudo ifconfig'  # Windows typo
# Jump functions (if functions in .bashrc, do not need to dot source as for scripts)
n() { cd ~/new_linux || return; ls; echo; }       # jump to new_linux
h() { cd ~ || return; ls; echo; }                 # jump to home
w() { cd ~/192.168.1.29-d || return; ls; echo; }  # jump to 'WHITE' PC SMB share
v() { cd ~/.vnc || return; ls; echo; }            # jump to .vnc

# tmux definitions
alias tt='tmux'
alias tkk='tmux kill-pane'
alias t-kill='tmux kill-pane'
alias t-help='echo -e \"TMUX COMMANDS\n=====\n\n\$(tmux list-commands)\n\nTMUX KEY BINDINGS\n=====\n\n\$(tmux list-keys)\n\n\n\" | less'
alias t-commands='tmux list-commands | less' # Show tmux commands, with less
alias t-keys='tmux list-keys | less' # Show key bindings, with less
alias tbuffer='tmux copy-mode'      # C-b,[ then up/down, pgup/pgdn
alias tff='tmux select-pane -t :.+' # Forward toggle through panes, C-b,
alias tbb='tmux select-pane -t :.-' # Backward toggle through panes
alias tpl='tmux resize-pane -L 5'   # Pane Resize Left 5
alias tpr='tmux resize-pane -R 5'   # Pane Resize Right 5
alias tpu='tmux resize-pane -U 5'   # Pane Resize Up 5
alias tpd='tmux resize-pane -D 5'   # Pane Resize Down 5
# 'horizontal' split means panes left-right, 'vertical' split means panes up-down
alias thh=\"tmux split-window -h -c '#{pane_current_path}'\"
alias tvv=\"tmux split-window -v -c '#{pane_current_path}'\"
trename() { tmux rename-session \$1; }
tswitch() { tmux switch-client -t \$1; }
tattach() { tmux attach-session -t \$1; }
alias tdetach='tmux detach'; alias texit='tdetach'
# toggle tmux mouse on/off
tmm() {
    current_status=\$(tmux show -g mouse | awk '{print \$2}')
    if [ \"\$current_status\" = \"on\" ]; then
        tmux set -g mouse off
        echo \"Mouse mode turned off.\"
    else
        tmux set -g mouse on
        echo \"Mouse mode turned on.\"
    fi
}
"

# Backup ~/.bashrc before making changes
cp ~/.bashrc ~/.bashrc.$(date +'%Y-%m-%d_%H-%M-%S').bak

# Iterate over each line in bashrc_block
while IFS= read -r line; do
    # Debugging: Print the line being processed
    # echo "Processing line: '$line'"

    # If the line is blank or contains only spaces/tabs, add a real blank line
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]]; then
        # Debugging: Check if it's a blank line
        echo "Detected blank or whitespace-only line."

        # Directly add a blank line without checking for its existence in ~/.bashrc
        echo "Adding blank line"
        echo "" >> ~/.bashrc
    # If the line starts with "#", check for whole line in ~/.bashrc
    elif [[ "$line" =~ ^# ]]; then
        if ! grep -Fxq "$line" ~/.bashrc; then
            echo "Adding comment: $line"
            echo "$line" >> ~/.bashrc
        fi
    # If the line starts with "alias" (up to and including "="), check for it in ~/.bashrc
    elif [[ "$line" =~ ^alias.*= ]]; then
        alias_name=$(echo "$line" | cut -d'=' -f1)
        if ! grep -q "^$alias_name=" ~/.bashrc; then
            echo "Adding alias: $line"
            echo "$line" >> ~/.bashrc
        fi
    # If the line starts with "export" (up to and including "="), check for it in ~/.bashrc
    elif [[ "$line" =~ ^export.*= ]]; then
        export_name=$(echo "$line" | cut -d'=' -f1)
        if ! grep -q "^$export_name=" ~/.bashrc; then
            echo "Adding export: $line"
            echo "$line" >> ~/.bashrc
        fi
    # If the line starts with "function" (up to and including the "{"), check for it in ~/.bashrc
    elif [[ "$line" =~ ^function.*\ \{ ]]; then
        func_name=$(echo "$line" | cut -d' ' -f2 | cut -d'(' -f1)
        if ! grep -q "^function $func_name" ~/.bashrc; then
            echo "Adding function: $line"
            echo "$line" >> ~/.bashrc
        fi
    # Handle multiline functions (those that start with "<functionname> () {" and end with "^\}" on a later line), we gather all lines
    elif [[ "$line" =~ ^.*\ \{ ]]; then
        func_start=$(echo "$line" | cut -d' ' -f1)
        if ! grep -q "$func_start" ~/.bashrc; then
            echo "Adding multiline function: $line"
            echo "$line" >> ~/.bashrc
            # Add the rest of the function until we find the closing brace
            while IFS= read -r next_line && [[ ! "$next_line" =~ ^\} ]]; do
                echo "$next_line" >> ~/.bashrc
            done
            echo "$next_line" >> ~/.bashrc # Append the closing brace
        fi
    fi
done <<< "$bashrc_block"

# Remove any blank lines, but only at the end of .bashrc, that may have been introduced due to how blank lines are added above
sed -i ':a; N; $!ba; s/\n[[:space:]]*\n*$//' ~/.bashrc
# :a; N; $!ba:             This reads the whole file into memory.
# s/\n[[:space:]]*\n*$//   Removes any empty lines or whitespace-only lines from the end of the file.

echo "Finished updating ~/.bashrc"

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # The script was sourced, so you can safely run the block here
    echo "$script_name was sourced, so 'source ~/.bashrc' will be run now"
    
    # Ensure BASHRC_FILE is set to the correct path
    BASHRC_FILE="$HOME/.bashrc"
    
    # Check if the .bashrc file exists
    if [[ -f "$BASHRC_FILE" ]]; then
        echo "Reloading .bashrc..."
        source "$BASHRC_FILE"
    else
        echo "Error: $BASHRC_FILE not found!"
        exit 1
    fi
fi
