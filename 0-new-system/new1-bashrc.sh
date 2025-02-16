#!/bin/bash

# Each line in 'bashrc_block' will be tested against .bashrc
# If that item exists with a different value, it will not alter it
# so by design does not mess up existing configurations (it just
# adds any elements not covered to the end of .bashrc).
#
# e.g. if 'export EDITOR=' is set (to vi or emacs or nano) the
# export EDITOR= line in here will not be added and the existing
# line will not be altered.
#
# Multi-line functions are treated as a single block; again, if a
# function with that name already exists, this script will not modify
# that, and will not add the new entry. Otherwise, the whole
# multi-line function from bashrc_block will be added to .bashrc
# so the whole function is cleanly added.

# Backup ~/.bashrc before making changes
BASHRC_FILE="$HOME/.bashrc"
cp "$BASHRC_FILE" "$BASHRC_FILE.$(date +'%Y-%m-%d_%H-%M-%S').bak"

# Block of text to check and add to .bashrc
# Make sure to escape " and \ in the below (change " to \" and change \n to \\n).
bashrc_block="
# new_linux definitions
####################

# Prompt before overwrite (-i interactive) for rm,cp,mv
# All scripts will ignore the -i scripts unless a script is sourced at runtime to include .bashrc
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Alias/Function/Export definitions
export EDITOR=vi
export PAGER=less
export LESS='-RFX'   # -R (ANSI colour), -F (exit if fit on one screen), X (disable clearing screen on exit)
export MANPAGER=less   # Set pager for 'man'
export CHEAT_PATHS=\"~/.cheat\"
export CHEAT_COLORS=true
git config --global core.pager less   # Set pager for 'git'
# glob expansion for vi, e.g. 'vi *myf*' then tab should expand *myf* to a matching file
complete -o filenames -o nospace -o bashdefault -o default vi
shopt -s checkwinsize   # At every prompt check if the window size has changed
shopt -s histappend     # Append commands to the bash history (~/.bash_history) instead of overwriting it
# Extended globbing
shopt -s extglob
# Standard Globbing (enabled by default): *, ?, [], e.g. *file[123] will match myfile1, myfile2, myfile3.
# Extended Globbing:
# ?(pattern), zero or one occurrence, e.g. ?(abc) matches abc or nothing.
# *(pattern), zero or more of the pattern, e.g. *(abc) matches abc, abcabc, or nothing.
# +(pattern), one or more occurrences of the pattern, e.g. +(abc) matches abc or abcabc but NOT nothing.
# @(pattern1|pattern2|...), matches exactly one of the specified patterns, e.g., @(jpg|png) matches jpg or png.
# !(pattern), matches anything except the pattern, e.g., !(abc) matches any string except abc.

h() {
    set +H; history -a;
    case \"\$1\" in
        \"\" | help) echo -e \"Usage:\\n  h all\\n  h f (or s)\\n  h n\\n  h clear\\n  h edit\\n  h uniq\\n  h top\\n  h cmds\\n  h hist\\n  h root\\n\" ;;
        all) history | sed 's/^[[:space:]]*[0-9]\+[[:space:]]*[0-9-]\{10\} [0-9:]\{8\} //' ;;
        f | s) history | sed 's/^[[:space:]]*[0-9]\+[[:space:]]*[0-9-]\{10\} [0-9:]\{8\} //' | grep -i --color=auto \"\$2\" ;;
        fd | sd) history | grep -i --color=auto \"\$2\" ;; 
        n) [[ \"\$2\" =~ ^[0-9]+$ ]] && history | tail -n \"\$2\" || echo \"Invalid number\" ;;
        clear) history -c && echo \"History cleared\" ;;
        edit) history -w && \${EDITOR:-vi} \"\$HISTFILE\" ;;
        uniq) history | sed 's/^[[:space:]]*[0-9]\+[[:space:]]*[0-9-]\{10\} [0-9:]\{8\} //' | sort -u ;;
        top) history | sed 's/^[[:space:]]*[0-9]\+[[:space:]]*[0-9-]\{10\} [0-9:]\{8\} //' | awk '{CMD[\$1]++} END {for (a in CMD) print CMD[a], a;}' | sort -nr | head -10 ;;
        cmds) history | sed 's/^[[:space:]]*[0-9]\+[[:space:]]*[0-9-]\{10\} [0-9:]\{8\} //' | awk '{print \$1}' | sort | uniq -c | sort -nr | head -20 ;;
        hist) history | sed 's/^[[:space:]]*[0-9]\+[[:space:]]*[0-9-]\{10\} [0-9:]\{8\} //' ;;
        root) history | sed 's/^[[:space:]]*[0-9]\+[[:space:]]*[0-9-]\{10\} [0-9:]\{8\} //' | grep -w sudo ;;
        *) [[ \"\$1\" =~ ^[0-9]+$ ]] && history | tail -n \"\$1\" || echo \"Invalid option\" ;;
    esac;
    set -H
}

alias hg='history | grep'       # 'history-grep'. After search, !201 will run item 201 in history
# https://www.digitalocean.com/community/tutorials/how-to-use-bash-history-commands-and-expansions-on-a-linux-vps
export HISTTIMEFORMAT=\"%F %T  \" HISTCONTROL=ignorespace:ignoreboth:erasedups HISTSIZE=1000000 HISTFILESIZE=1000000000   # make history very big and show date-time when run 'history'
# Word Designatores: ls /etc/, cd !!:1 (:0 is the initial word), !!:1*, !!:1-$, !!:*     'cat /etc/hosst', then type '^hosst^hosts^' will immediately run the fixed command.
# Modifiers: 'cat /etc/hosts', cd !!:$:h (will cd into /etc/ as :h chops the 'head' off, :t, 'tail' will remove 'cat /etc/', :r to remove trailing extension, :r:r to remove .tar.gz, :p is just to 'print', 'find ~ -name \"file1\"', try !119:0:p / !119:2*:p

# These rely on the 'a' script that will be in the scripts folder (will not set if that script is not present)
if type -t a >/dev/null 2>&1; then alias ai='a i'; fi
if type -t a >/dev/null 2>&1; then alias av='a v'; fi
if type -t a >/dev/null 2>&1; then alias ah='a h'; fi

# Simple aliases to open various configuration scripts
alias bashrc='vi ~/.bashrc'                 # Edit .bashrc (user)
alias vimrc='vi ~/.vimrc'                   # Edit .vimrc (user)
alias vimrcroot='sudo vi /etc/vim/vimrc'    # Edit vimrc (system)
alias vimrcsudo='sudo vi /etc/vim/vimrc'    # Edit vimrc (system)
alias initvim='vi ~/.config/nvim/init.vim'  # Edit neovim configuration
alias nvimrc='vi ~/.config/nvim/init.vim'   # Edit neovim configuration
alias smb='sudo vi /etc/samba/smb.conf'     # Edit Samba configuration
alias samba='sudo vi /etc/samba/smb.conf'   # Edit Samba configuration
alias smbconf='sudo vi /etc/samba/smb.conf' # Edit Samba configuration
alias fstab='sudo vi /etc/fstab'            # Edit Filesystem Table
alias exports='sudo vi /etc/exports'        # Edit NFS exports

# Simple helpers, cd.., cx, cxx, ls., ll., ifconfig, ipconfig, find1 (wip as a simple find tool ignoring unlikely locations)
alias cd..='cd ..'
alias cx='chmod +x'              # chmod add execute
cxx() { chmod +x \$1; ./\$1; }   # chmod \$1 and then run it
alias ls.='ls -d .*'
alias ll.='ls -ald .*'
alias ifconfig='sudo ifconfig'  # 'ifconfig' has 'command not found' if run without sudo (apt install net-tools)
alias ipconfig='sudo ifconfig'  # Windows typo
alias find1='find /etc /usr /opt /var ~ \\( -type d -o -name \"*.conf\" -o -name \"*.cfg\" -o -name \"*.sh\" -o -name \"*.bin\" -o -name \"*.exe\" -o -name \"*.txt\" -o -name \"*.log\" -o -name \"*.doc\" \\) 2>/dev/null'

# This function must be in .bashrc to have visibility of all loaded shell functions and aliases
def() {
    if [ -z \"\$1\" ]; then
        declare -F; printf \"\\nAll defined functions ('declare -F').\\n\"
        printf \"'def <name>' to show definitions of functions, aliases, built-ins, and scripts.\\n\\n\"
        return
    fi
    local OVERLAPS=()   # Track overlaps in an array, i.e. where the item is in more than one category
    local PAGER=\"cat\"   # Use 'cat' if 'batcat' is not available
    if command -v batcat >/dev/null 2>&1; then   # Only use 'batcat' if available
        PAGER=\"batcat -pp -l bash\"
    fi
    if declare -F \"\$1\" >/dev/null 2>&1; then   # check for a 'Function'
        declare -f \"\$1\" | \$PAGER; OVERLAPS+=(\"Function\"); echo; echo \"Function '\$1':\"; 
    fi
    if alias \"\$1\" >/dev/null 2>&1; then   # check for an 'Alias'
        alias \"\$1\" | \$PAGER; OVERLAPS+=(\"Alias\"); echo; echo \"Alias '\$1':\"
    fi
    if type -t \"\$1\" | grep -q \"builtin\"; then   # check for a 'built-in command'
        help \"\$1\" | \$PAGER; OVERLAPS+=(\"Built-in\"); echo; echo \"Built-in Command '\$1':\"
    fi
    if command -v \"\$1\" >/dev/null 2>&1; then   # check for an 'external script'
        local SCRIPT_PATH=\$(command -v \"\$1\")
        if [[ -f \"\$SCRIPT_PATH\" ]]; then
            \$PAGER \"\$SCRIPT_PATH\"; OVERLAPS+=(\"Script\"); echo; echo \"'\$1' is a script, located at '\$SCRIPT_PATH':\" 
        fi
    fi
    # Display overlaps
    if [ \${#OVERLAPS[@]} -gt 1 ]; then echo -e \"\\033[0;31mNote: '\$1' is a \${OVERLAPS[*]}.\\033[0m\"; fi
    # If no matches were found
    if [ \${#OVERLAPS[@]} -eq 0 ]; then echo \"No function, alias, built-in, or script found for '\$1'.\"; fi;
}

# Jump functions (cannot be in scripts as would need to dotsource each, so keep in .bashrc)
n()  { cd ~/new_linux || return; ls; }            # jump to new_linux
0g() { cd ~/new_linux/0-games || return; ls; }    # jump to new_linux/0-games
0h() { cd ~/new_linux/0-help || return; ls; }     # jump to new_linux/0-help
0i() { cd ~/new_linux/0-install || return; ls; }  # jump to new_linux/0-install
0n() { cd ~/new_linux/0-notes || return; ls; }    # jump to new_linux/0-notes
0ns() { cd ~/new_linux/0-new-system || return; ls; } # jump to new_linux/0-new-system
0s() { cd ~/new_linux/0-scripts || return; ls; }  # jump to new_linux/0-scripts
v()  { cd ~/.vnc || return; ls; }                 # jump to .vnc
w()  { cd ~/new_linux/0-wip || return; ls; }      # jump to 0-wip
white() { cd ~/192.168.1.29-d || return; ls; }   # jump to 'WHITE' PC SMB share

# tmux shortcuts
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
# 'horizontal' split means the line is vertical  |,  i.e. one pane on left, and another on right
# 'vertical' split means the line is horizontal ---, i.e. one pane at top, and another pane at bottom
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

# Capture the first non-empty line of $bashrc_block, this is the header line
# If it currently exists, the script first offers to *remove* everything after
# the header line, so that all of the $bashrc_block can be updated together.
first_non_empty_line=$(echo "$bashrc_block" | sed -n '/[^[:space:]]/s/^[[:space:]]*//p' | head -n 1)

# Ensure the variable is not empty
if [[ -z "$first_non_empty_line" ]]; then
    echo "No valid content found in bashrc_block. Skipping removal."
    exit 0
fi

# Check if this line exists in .bashrc
if ! grep -Fxq "$first_non_empty_line" "$BASHRC_FILE"; then
    echo "No match for the header line in the \$bashrc_block was found in .bashrc."
    echo "so will skip full removal and move to a line by line add of \$bashrc_block."
else
    # Prompt user for confirmation to wipe from the found line downwards
    echo "Do you want to wipe the existing bashrc_block from .bashrc starting from: $first_non_empty_line ? (y/n)"
    read -r wipe_confirm

    if [[ "$wipe_confirm" =~ ^[Yy]$ ]]; then
        # Delete from the found line to the end of the file
        sed -i "/$(printf '%s\n' "$first_non_empty_line" | sed 's/[.[\*^$]/\\&/g')/,\$d" "$BASHRC_FILE"
        echo "Removed from '$first_non_empty_line' to the end of .bashrc."
    else
        echo "No changes made to .bashrc."
    fi
fi

# Always add the first non-empty line to .bashrc, regardless of removals
# echo "$first_non_empty_line" >> "$BASHRC_FILE"
# echo "Added '$first_non_empty_line' to .bashrc."

read -p "Press Enter to continue..."

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
