#!/bin/bash

# Each line in 'bashrc_block' will be tested against .bashrc
# If that item exists with a different value, it will not alter it.
# It does not check the whole line, e.g. for 'export EDITOR=vi'
# if this was set to 'export EDITOR=emacs' or 'nano' this will not
# be changed as it will check for 'eport EDITOR=' and if that is
# found it will skip to the next entry.
# Multi-line functions are treated as a single block; again, if a
# function with the name exists, it will leave that, but if not,
# the whole multi-line function from bashrc_block will be added
# to .bashrc

# Backup ~/.bashrc before making changes
BASHRC_FILE="$HOME/.bashrc"
cp "$BASHRC_FILE" "$BASHRC_FILE.$(date +'%Y-%m-%d_%H-%M-%S').bak"

# Block of text to check and add to .bashrc
# Make sure to escape " and \ in the below (change " to \" and change \n to \\n).
bashrc_block="
# user alias/function/export definitions
export EDITOR=vi
export PAGER=less
export LESS='-RFX'   # -R (ANSI colour), -F (exit if fit on one screen), X (disable clearing screen on exit)
export MANPAGER=less   # Set pager for 'man'
export CHEAT_PATHS=\"~/.cheat\"
export CHEAT_COLORS=true
git config --global core.pager less   # Set pager for 'git'
# glob expansion for vi, e.g. 'vi *myf*' then tab should expand *myf* to a matching file
complete -o filenames -o nospace -o bashdefault -o default vi
# Extended globbing
shopt -s extglob
# Standard Globbing (enabled by default): *, ?, [], e.g. *file[123] will match myfile1, myfile2, myfile3.
# Extended Globbing:
# ?(pattern), zero or one occurrence, e.g. ?(abc) matches abc or nothing.
# *(pattern), zero or more of the pattern, e.g. *(abc) matches abc, abcabc, or nothing.
# +(pattern), one or more occurrences of the pattern, e.g. +(abc) matches abc or abcabc but NOT nothing.
# @(pattern1|pattern2|...), matches exactly one of the specified patterns, e.g., @(jpg|png) matches jpg or png.
# !(pattern), matches anything except the pattern, e.g., !(abc) matches any string except abc.
# Enhanced history tool if 'hh' script is on PATH
h() {
    export HH_INVOCATION=1   # Required to invoke hh
    history -a               # Save the current session's unsaved history to \$HISTFILE
    if command -v hh >/dev/null 2>&1; then hh \"\$@\"
    else history \"\$@\"     # If 'hh' does not exist, fallback to 'history'
    fi
    unset HH_INVOCATION
}
alias vimrc='vi ~/.vimrc'
alias bashrc='vi ~/.bashrc'
alias nvimrc='vi ~/.config/nvim/init.vim'
alias initvim='vi ~/.config/nvim/init.vim'
alias vimrcroot='sudo vi /etc/vim/vimrc'
alias vimrcsudo='sudo vi /etc/vim/vimrc'
alias cd..='cd ..'
alias ..='cd ..'
alias cx='chmod +x'              # chmod add execute
cxx() { chmod +x \$1; ./\$1; }   # chmod \$1 and then run it
alias ls.='ls -d .*'
alias ll.='ls -ald .*'
# def: Get definitions, expand alias and function definitions that match \$1 
defshow() {
    if [ -z \"\$1\" ]; then
        declare -F
        printf \"\\nAll defined functions ('declare -F').\\n\"
        printf \"'def <name>' to show function definition, alias, built-in, or script.\\n\\n\"
        return
    fi
    local OVERLAPS=()   # Track overlaps in an array, i.e. where the item is in more than one category
    local BAT=\"cat\"   # Check if batcat is available
    if command -v batcat >/dev/null 2>&1; then BAT=\"batcat -pp -l bash\"; fi
    # Check if it's a function
    if declare -F \"\$1\" >/dev/null 2>&1; then
        echo \"Function '\$1':\"
        declare -f \"\$1\" | \$BAT
        OVERLAPS+=(\"Function\")
    fi
    # Check if it's an alias
    if alias \"\$1\" >/dev/null 2>&1; then
        echo \"Alias '\$1':\"
        alias \"\$1\" | \$BAT
        OVERLAPS+=(\"Alias\")
    fi
    # Check if it's a built-in command
    if type -t \"\$1\" | grep -q \"builtin\"; then
        echo \"Built-in Command '\$1':\"
        help \"\$1\" | \$BAT
        OVERLAPS+=(\"Built-in\")
    fi
    # Check if it's an external script
    if command -v \"\$1\" >/dev/null 2>&1; then
        local SCRIPT_PATH=\$(command -v \"\$1\")
        if [[ -f \"\$SCRIPT_PATH\" ]]; then
            echo \"Script '\$1' is at '\$SCRIPT_PATH':\"
            \$BAT \"\$SCRIPT_PATH\"
            OVERLAPS+=(\"Script\")
        fi
    fi
    # Display overlaps
    if [ \${#OVERLAPS[@]} -gt 1 ]; then echo -e \"\\033[0;31mNote: '\$1' is a \${OVERLAPS[*]}.\\033[0m\"; fi
    # If no matches were found
    if [ \${#OVERLAPS[@]} -eq 0 ]; then echo \"No function, alias, built-in, or script found for '\$1'.\"; fi;
}
# The 'a' script should be in the scripts folder
if type -t a >/dev/null 2>&1; then alias ai='a i'; fi
if type -t a >/dev/null 2>&1; then alias av='a v'; fi
if type -t a >/dev/null 2>&1; then alias ah='a h'; fi
alias hg='history | grep'       # 'history-grep'. After search, !201 will run item 201 in history
shopt -s checkwinsize   # At every prompt check if the window size has changed
shopt -s histappend     # Append commands to the bash history (~/.bash_history) instead of overwriting it
# https://www.digitalocean.com/community/tutorials/how-to-use-bash-history-commands-and-expansions-on-a-linux-vps
export HISTTIMEFORMAT=\"%F %T  \" HISTCONTROL=ignorespace:ignoreboth:erasedups HISTSIZE=1000000 HISTFILESIZE=1000000000   # make history very big and show date-time when run 'history'
# Word Designatores: ls /etc/, cd !!:1 (:0 is the initial word), !!:1*, !!:1-$, !!:*     'cat /etc/hosst', then type '^hosst^hosts^' will immediately run the fixed command.
# Modifiers: 'cat /etc/hosts', cd !!:$:h (will cd into /etc/ as :h chops the 'head' off, :t, 'tail' will remove 'cat /etc/', :r to remove trailing extension, :r:r to remove .tar.gz, :p is just to 'print', 'find ~ -name \"file1\"', try !119:0:p / !119:2*:p

alias ifconfig='sudo ifconfig'  # 'ifconfig' has 'command not found' if run without sudo (apt install net-tools)
alias ipconfig='sudo ifconfig'  # Windows typo
alias find1='find /etc /usr /opt /var ~ \\( -type d -o -name \"*.conf\" -o -name \"*.cfg\" -o -name \"*.sh\" -o -name \"*.bin\" -o -name \"*.exe\" -o -name \"*.txt\" -o -name \"*.log\" -o -name \"*.doc\" \\) 2>/dev/null'

# Jump functions. Adding to scripts would require dotsource, so add/change as required in .bashrc to include in main shell
n()  { cd ~/new_linux || return; ls; }            # jump to new_linux
0h() { cd ~/new_linux/0-help || return; ls; }     # jump to new_linux/0-help
0i() { cd ~/new_linux/0-install || return; ls; }  # jump to new_linux/0-install
0n() { cd ~/new_linux/0-notes || return; ls; }    # jump to new_linux/0-notes
0ns() { cd ~/new_linux/0-new-system || return; ls; } # jump to new_linux/0-new-system
0s() { cd ~/new_linux/0-scripts || return; ls; }  # jump to new_linux/0-scripts
v()  { cd ~/.vnc || return; ls; }                 # jump to .vnc
w()  { cd ~/new_linux/0-wip || return; ls; }      # jump to 0-wip
white()  { cd ~/192.168.1.29-d || return; ls; }   # jump to 'WHITE' PC SMB share
# h() { cd ~ || return; ls; }   # jump to home, commented out as using 'h' for history (just use 'cd' to jump to home anyway)

# tmux definitions
alias tt='tmux'
alias tlist='tmux list'
alias tkk='tmux kill-pane'; alias tkill='tmux kill-pane'
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
tattach() { tmux attach-session -t \$1; }; alias tatt='tmux attach' # just attach to last active
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
        function)
            func_name=$(echo "$line" | cut -d' ' -f1)
            if ! grep -q "^$func_name" "$BASHRC_FILE"; then
                echo "Adding function: $func_name"
                echo "$line" >> "$BASHRC_FILE"
                while IFS= read -r next_line && [[ ! "$next_line" =~ ^\} ]]; do
                    echo "$next_line" >> "$BASHRC_FILE"
                done
                echo "$next_line" >> "$BASHRC_FILE" # Add closing brace
            else
                echo "Function $func_name already exists. Skipping."
            fi
            ;;
        complete|shopt|if|fi)
            if ! grep -qF "$line" "$BASHRC_FILE"; then
                echo "Adding $type: $line"
                echo "$line" >> "$BASHRC_FILE"
            else
                echo "$type $line already exists. Skipping."
            fi
            ;;
        *)
            echo "Adding unclassified line: $line"
            if ! grep -qF "$line" "$BASHRC_FILE"; then
                echo "$line" >> "$BASHRC_FILE"
            else
                echo "Line already exists. Skipping."
            fi
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
    elif [[ "$line" =~ ^complete ]]; then
        add_line_if_not_exists "$line" "complete"
    elif [[ "$line" =~ ^shopt ]]; then
        add_line_if_not_exists "$line" "shopt"
    elif [[ "$line" =~ ^if ]]; then
        add_line_if_not_exists "$line" "if"
    elif [[ "$line" =~ ^fi ]]; then
        add_line_if_not_exists "$line" "fi"
    elif [[ "$line" =~ \ \{ ]]; then
        add_line_if_not_exists "$line" "function"
    elif [[ -z "$line" ]]; then
        echo >> "$BASHRC_FILE"  # Preserve blank lines
    else
        add_line_if_not_exists "$line" "other"
    fi
done <<< "$bashrc_block"

# Could use here-document above as <<< here-string threw vim formatting off at times
# done <<EOF
# $bash_block
# EOF

# Blank lines can be introduced if run multiple times; remove them here
sed -i ':a; N; $!ba; s/\n[[:space:]]*\n*$//' "$BASHRC_FILE"

echo
echo "Finished updating $BASHRC_FILE."

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  # Script is sourced
  echo "This script is sourced, so will update environment now..."
  source ~/.bashrc
else
  # Script is executed
  echo "This script is not sourced, so to apply changes, run: source ~/.bashrc"
fi



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


# Everything below here does nothing, they are just ANSI colour definitions.
# Leaving these here in case of use in other scripts.
#
# Some examples of use after adding these definitions to scripts:
# echo -e "${BOLD_RED}Error:${NC} Something went wrong!"
# echo -e "${GREEN}Success:${NC} Operation completed."
# PS1="${BOLD_GREEN}\u${NC}@${BOLD_BLUE}\h${NC}:${BOLD_YELLOW}\w${NC}\$ "

# BLACK
BLACK='\033[0;30m'
BLACK_BOLD='\033[1;30m'
BLACK_UNDERLINE='\033[4;30m'
BLACK_HIGH_INTENSITY='\033[0;90m'
BLACK_BOLD_HIGH_INTENSITY='\033[1;90m'
BLACK_BG='\033[40m'
BLACK_BG_HIGH_INTENSITY='\033[0;100m'

# RED
RED='\033[0;31m'
RED_BOLD='\033[1;31m'
RED_UNDERLINE='\033[4;31m'
RED_HIGH_INTENSITY='\033[0;91m'
RED_BOLD_HIGH_INTENSITY='\033[1;91m'
RED_BG='\033[41m'
RED_BG_HIGH_INTENSITY='\033[0;101m'

# GREEN
GREEN='\033[0;32m'
GREEN_BOLD='\033[1;32m'
GREEN_UNDERLINE='\033[4;32m'
GREEN_HIGH_INTENSITY='\033[0;92m'
GREEN_BOLD_HIGH_INTENSITY='\033[1;92m'
GREEN_BG='\033[42m'
GREEN_BG_HIGH_INTENSITY='\033[0;102m'

# YELLOW
YELLOW='\033[0;33m'
YELLOW_BOLD='\033[1;33m'
YELLOW_UNDERLINE='\033[4;33m'
YELLOW_HIGH_INTENSITY='\033[0;93m'
YELLOW_BOLD_HIGH_INTENSITY='\033[1;93m'
YELLOW_BG='\033[43m'
YELLOW_BG_HIGH_INTENSITY='\033[0;103m'

# BLUE
BLUE='\033[0;34m'
BLUE_BOLD='\033[1;34m'
BLUE_UNDERLINE='\033[4;34m'
BLUE_HIGH_INTENSITY='\033[0;94m'
BLUE_BOLD_HIGH_INTENSITY='\033[1;94m'
BLUE_BG='\033[44m'
BLUE_BG_HIGH_INTENSITY='\033[0;104m'

# PURPLE
PURPLE='\033[0;35m'
PURPLE_BOLD='\033[1;35m'
PURPLE_UNDERLINE='\033[4;35m'
PURPLE_HIGH_INTENSITY='\033[0;95m'
PURPLE_BOLD_HIGH_INTENSITY='\033[1;95m'
PURPLE_BG='\033[45m'
PURPLE_BG_HIGH_INTENSITY='\033[0;105m'

# CYAN
CYAN='\033[0;36m'
CYAN_BOLD='\033[1;36m'
CYAN_UNDERLINE='\033[4;36m'
CYAN_HIGH_INTENSITY='\033[0;96m'
CYAN_BOLD_HIGH_INTENSITY='\033[1;96m'
CYAN_BG='\033[46m'
CYAN_BG_HIGH_INTENSITY='\033[0;106m'

# WHITE
WHITE='\033[0;37m'
WHITE_BOLD='\033[1;37m'
WHITE_UNDERLINE='\033[4;37m'
WHITE_HIGH_INTENSITY='\033[0;97m'
WHITE_BOLD_HIGH_INTENSITY='\033[1;97m'
WHITE_BG='\033[47m'
WHITE_BG_HIGH_INTENSITY='\033[0;107m'

# Reset
NC='\033[0m' # No Color

# Formatting Options
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'
BLINK='\033[5m'
INVERT='\033[7m'
HIDDEN='\033[8m'
STRIKETHROUGH='\033[9m'
RESET_BOLD='\033[21m'
RESET_DIM='\033[22m'
RESET_UNDERLINE='\033[24m'
RESET_BLINK='\033[25m'
RESET_INVERT='\033[27m'
RESET_HIDDEN='\033[28m'
RESET_STRIKETHROUGH='\033[29m'

