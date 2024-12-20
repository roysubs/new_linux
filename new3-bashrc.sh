
#!/bin/bash

BASHRC_FILE="$HOME/.bashrc"

# Backup ~/.bashrc before making changes
cp "$BASHRC_FILE" "$BASHRC_FILE.$(date +'%Y-%m-%d_%H-%M-%S').bak"

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
# apti/ii (install), aptr/rr (remove), aptu/uu (update-upgrade)
alias apti='echo apti/ii (install), aptr/rr (remove), aptu/uu (update-upgrade); sudo apt install'
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
alias ifconfig='sudo ifconfig'  # 'ifconfig' has 'command not found' if run without sudo (apt install net-tools)
alias ipconfig='sudo ifconfig'  # Windows typo

# Jump functions. Adding to scripts would require dotsource, so add/change as required in .bashrc to include in main shell
n() { cd ~/new_linux || return; ls; echo; }       # jump to new_linux
h() { cd ~ || return; ls; echo; }                 # jump to home
w() { cd ~/192.168.1.29-d || return; ls; echo; }  # jump to 'WHITE' PC SMB share
v() { cd ~/.vnc || return; ls; echo; }            # jump to .vnc

# tmux definitions
alias tt='tmux'
alias tkk='tmux kill-pane'
alias tkill='tmux kill-pane'
alias thelp='echo -e \"TMUX COMMANDS\n=====\n\n\$(tmux list-commands)\n\nTMUX KEY BINDINGS\n=====\n\n\$(tmux list-keys)\n\n\n\" | less'
alias tcommands='tmux list-commands | less' # Show tmux commands, with less
alias tkeys='tmux list-keys | less' # Show key bindings, with less
alias tbuffer='tmux copy-mode'      # C-b,[ then up/down, pgup/pgdn
alias tff='tmux select-pane -t :.+' # Forward toggle through panes, C-b,
alias tbb='tmux select-pane -t :.-' # Backward toggle through panes
alias tpl='tmux resize-pane -L 5'   # Pane Resize Left 5
alias tpr='tmux resize-pane -R 5'   # Pane Resize Right 5
alias tpu='tmux resize-pane -U 5'   # Pane Resize Up 5
alias tpd='tmux resize-pane -D 5'   # Pane Resize Down 5
# 'horizontal' split means the line is vertical, so panes are left/right
# 'vertical' split means the line is horizontal, so panes are up/down
alias thh=\"tmux split-window -h -c '#{pane_current_path}'\"
alias tvv=\"tmux split-window -v -c '#{pane_current_path}'\"
trename() { tmux rename-session \$1; };    alias tren='trename'
tswitch() { tmux switch-client -t \$1; };  alias tswi='tswitch'
tattach() { tmux attach-session -t \$1; }; alias tatt='tattach'
alias tdetach='tmux detach';               alias tdet='tdetach'  # C-b, d
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

# Function to check and add lines
add_line_if_not_exists() {
    local line="$1"
    local type="$2"

    case $type in
        alias)
            alias_name=$(echo "$line" | cut -d'=' -f1)
            if ! grep -q "^$alias_name=" "$BASHRC_FILE"; then
                echo "Adding alias: $line"
                echo "$line" >> "$BASHRC_FILE"
            else
                echo "Alias $alias_name already exists. Skipping."
            fi
            ;;
        export)
            export_name=$(echo "$line" | cut -d'=' -f1)
            if ! grep -q "^$export_name=" "$BASHRC_FILE"; then
                echo "Adding export: $line"
                echo "$line" >> "$BASHRC_FILE"
            else
                echo "Export $export_name already exists. Skipping."
            fi
            ;;
        comment)
            if ! grep -qF "$line" "$BASHRC_FILE"; then
                echo "Adding comment: $line"
                echo "$line" >> "$BASHRC_FILE"
            else
                echo "Comment already exists. Skipping."
            fi
            ;;
        *)
            echo "Unknown type: $type"
            ;;
    esac
}

# Process each line in the block
while IFS= read -r line; do
    if [[ "$line" =~ ^# ]]; then
        add_line_if_not_exists "$line" "comment"
    elif [[ "$line" =~ ^alias ]]; then
        add_line_if_not_exists "$line" "alias"
    elif [[ "$line" =~ ^export ]]; then
        add_line_if_not_exists "$line" "export"
    elif [[ "$line" =~ \ \{ ]]; then
        # Handle multiline functions
        func_start=$(echo "$line" | cut -d' ' -f1)
        if ! grep -q "^$func_start" "$BASHRC_FILE"; then
            echo "Adding multiline function: $line"
            echo "$line" >> "$BASHRC_FILE"
            # Add the rest of the function until we find the closing brace
            while IFS= read -r next_line && [[ ! "$next_line" =~ ^\} ]]; do
                echo "$next_line" >> "$BASHRC_FILE"
            done
            echo "$next_line" >> "$BASHRC_FILE" # Append the closing brace
        else
            echo "Function $func_start already exists. Skipping."
        fi
    elif [[ -z "$line" ]]; then
        # Add blank lines directly
        echo >> "$BASHRC_FILE"
    fi
done <<EOF
$bash_block
EOF
# done <<< "$bashrc_block"  # Use here-document above as <<< here-string throws vim formatting off

# Blank lines can be introduced by the above; remove them here
sed -i ':a; N; $!ba; s/\n[[:space:]]*\n*$//' "$BASHRC_FILE"

echo "Finished updating $BASHRC_FILE. To apply changes, run: source ~/.bashrc"
