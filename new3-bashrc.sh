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
# def: Get definitions, expand alias and function definitions that match \$1 
def() {
    if [ -z \"\$1\" ]; then
        declare -F
        printf \"\\nAbove listing is all defined functions 'declare -F' (use def <func-name> to show function contents)\\nType 'alias' to show all aliases (def <alias-nam> to show alias definition, where 'def' uses 'command -V <name>')\\n\\n\"
    elif type bat >/dev/null 2>&1; then
        command -V \$1 | bat -pp -l bash
    else
        command -V \$1
    fi
}
# a: Fast apt, with concise history 'h' and detailed info/depends/contents 'x'
a() {
    if [ \$# -eq 0 ]; then
        echo \"Usage: a [option] <package>\"
        echo \"Options:\"
        echo \"  i <package>     Install a package\"
        echo \"  h               History install/remove/upgrade\"
        echo \"  r <package>     Remove a package\"
        echo \"  s <package>     Search for a package\"
        echo \"  u               Update package lists\"
        echo \"  uu              Update and upgrade packages\"
        echo \"  v <package>     Show version of a package\"
        echo \"  x <package>     Show package info, dependencies, and contents\"
        return
    fi
    option=\$1
    package=\$2
    case \"\$option\" in
        i) sudo apt install \"\$package\" ;;
        h) zgrep -E '^(Start-Date|Commandline:.*(install|remove|upgrade))' /var/log/apt/history.log* | sed -n '/^Start-Date/{h;n;s/^Commandline: //;H;x;s/\\n/ /;p}' | sed -E 's|Start-Date: ||;s|/usr/bin/apt ||' | grep -v 'Start-Date:' ;;
        r) sudo apt remove \"\$package\" ;;
        s) apt search \"\$package\" ;;
        u) sudo apt update ;;
        uu) sudo apt update && sudo apt upgrade && sudo apt autoremove ;;
        v) apt-cache policy \"\$package\" | grep Installed ;;
        x)
            echo; if grep -q \"Mint\" /etc/os-release; then apt show \"\$package\"
            else apt info \"\$package\"; fi
            echo; read -n 1 -s -r -p \"Press any key to show package dependencies\"
            apt-cache depends \"\$package\"
            echo; read -n 1 -s -r -p \"Press any key to show package contents\"
            if command -v apt-file >/dev/null 2>&1; then apt-file list \"\$package\"
            else echo \"Install apt-file to view package contents\"; fi
            ;;
        *) echo \"Invalid option. Use 'a' without arguments to see usage.\" ;;
    esac
}
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
done <<< "$bashrc_block"  # Use here-document above as <<< here-string throws vim formatting off
# done <<EOF
# $bash_block
# EOF

# Blank lines can be introduced if run multiple times; remove them here
sed -i ':a; N; $!ba; s/\n[[:space:]]*\n*$//' "$BASHRC_FILE"

echo "Finished updating $BASHRC_FILE. To apply changes, run: source ~/.bashrc"


# a h option: zgrep -E '^(Start-Date|Commandline:.*(install|remove|upgrade))' /var/log/apt/history.log* | sed -n '/^Start-Date/{h;n;s/^Commandline: //;H;x;s/\\n/ /;p}' | sed -E 's|Start-Date: ||;s|/usr/bin/apt ||' | grep -v 'Start-Date:' ;;
# zgrep history.log* is used instead of grep history.log to also look inside rotated logs
# First sed:   sed -n '/^Start-Date/{h;n;s/^Commandline:
# Combines Start-Date with the following Commandline
#    h: Store the Start-Date line in the hold space.
#    n: Move to the next line (Commandline).
#    s/^Commandline: //: Remove the Commandline: prefix.
#    H: Append the processed line to the hold space.
#    x: Exchange hold and pattern space to combine lines.
#    s/\n/ /: Replace the newline between Start-Date and Commandline with a space.
#    p: Print the result.
# Second sed:
# Cleans up the output by: Removing Start-Date:. Removing /usr/bin/apt.
# Final grep: removes redundant lines containing 'Start-Date:'
