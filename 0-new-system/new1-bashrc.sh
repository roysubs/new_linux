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

# If -clean is invoked, then the old block will be removed from .bashrc and replaced
CLEAN_MODE=false
if [[ "$1" == "--clean" ]]; then
    CLEAN_MODE=true
fi

# Block of text to check and add to .bashrc
# Make sure to escape " and \ in the below (change " to \" and change \n to \\n).
bashrc_block="
# new_linux definitions
####################
# Note: Put manually added .bashrc definitionas *above* this section, as 'new1-bashrc.sh --clean'
#       will delete everything from the '# new_linux definitions' to the end of the file(!)

# Prompt before overwrite (-i interactive) for rm,cp,mv
# All scripts will ignore the -i scripts unless a script is sourced at runtime to include .bashrc
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

alias ls='ls --color=auto'  # Add color output by default
alias ls.='ls -d .*'        # -d shows only the directory, not the contents (of .config etc)
alias la='ls -A'            #
alias ll.='ls -ald .*'
alias ll='ls -l'
alias l='ls -CF'

# Alias/Function/Export definitions
export EDITOR=vi
export PAGER=less
export LESS='-RFX'    # -R (ANSI colour), -F (exit if fit on one screen), X (disable clearing screen on exit)
export MANPAGER=less    # Set pager for 'man'
export CHEAT_PATHS=\"~/.cheat\"
export CHEAT_COLORS=true
if command -v git &> /dev/null; then git config --global core.pager less; fi    # Set pager for 'git'
# glob expansion for vi, e.g. 'vi *myf*' then tab should expand *myf* to a matching file
complete -o filenames -o nospace -o bashdefault -o default vi
shopt -s checkwinsize    # At every prompt check if the window size has changed
# Extended globbing
shopt -s extglob
# Standard Globbing (enabled by default): *, ?, [], e.g. *file[123] will match myfile1, myfile2, myfile3.
# Extended Globbing:
# ?(pattern), zero or one occurrence, e.g. ?(abc) matches abc or nothing.
# *(pattern), zero or more of the pattern, e.g. *(abc) matches abc, abcabc, or nothing.
# +(pattern), one or more occurrences of the pattern, e.g. +(abc) matches abc or abcabc but NOT nothing.
# @(pattern1|pattern2|...), matches exactly one of the specified patterns, e.g., @(jpg|png) matches jpg or png.
# !(pattern), matches anything except the pattern, e.g., !(abc) matches any string except abc.

# History settings and 'h' History helper function
shopt -s histappend      # Append commands to the bash history (~/.bash_history) instead of overwriting it
export HISTTIMEFORMAT=\"%F %T  \" HISTCONTROL=ignorespace:ignoreboth:erasedups HISTSIZE=1000000 HISTFILESIZE=1000000000    # make history very big and show date-time

# h: History Tool. Must be in .bashrc (if it is in a script, then it will be in a subshell, and so cannot view full history)
h() {
    case \"\$1\" in
        \"\" ) # Default case when no arguments are given (show main help)
            echo -e \"History Tool. Usage: h <option> [string]\\n  a|an|ad|ab    show all history (a full, an numbers only, ad datetime only, ab bare commands)\\n  f|fn|fd|fb    find string (f full, fn numbers only, fd datetime only, fb bare commands)\\n  n <num>      Show last N history entries (full)\\n  help          Show extended help from 'h-history' script\\n  clear         Clear the history\\n  edit          Edit the history file in your editor\\n  uniq          Show unique history entries (bare)\\n  top           Show top 10 most frequent commands (bare roots)\\n  topn <N>     Show top N most used commands\\n  cmds          Show top 20 most frequent command roots (bare)\\n  root          Show commands run with sudo (bare)\\n  backup <filepath>  Backup history to 'filepath'\" ;; # Removed 'r' and trailing \\n
        a) history ;; # Show full history with numbers and dates
        an) history | sed 's/\\s*[0-9-]\\{10\\}\\s*[0-9:]\\{8\\}\\s*/ /' ;; # Show numbers only, remove date/time
        ad) history | sed 's/^[[:space:]]*[0-9]\\+[[:space:]]*//' ;; # Show datetime only, remove numbers
        ab) history | sed 's/^[[:space:]]*[0-9]\\+[[:space:]]*[0-9-]\\{10\\} [0-9:]\\{8\\} /#/' ;; # Show bare commands (no numbers or date/time), prefix each command with # as dangerous if copy and paste raw commands
        f | s) history | grep -i --color=auto \"\$2\" ;; # Find in full history (with numbers and dates)
        fn | sn) history | sed 's/\\s*[0-9-]\\{10\\}\\s*[0-9:]\\{8\\}\\s*/ /' | grep -i --color=auto \"\$2\" ;; # Find in history with numbers only
        fd | sd) history | sed 's/^[[:space:]]*[0-9]\\+[[:space:]]*//' | grep -i --color=auto \"\$2\" ;; # Find in history with datetime only
        fb | sb) history | sed 's/^[[:space:]]*[0-9]\\+[[:space:]]*[0-9-]\\{10\\} [0-9:]\\{8\\} /#/' | grep -i --color=auto \"\$2\" ;; # Find in bare history (no numbers or date/time), prefix each command with # as dangerous if copy and paste raw commands
        n) [[ \"\$2\" =~ ^[0-9]+\$ ]] && history | tail -n \"\$2\" || echo \"Invalid number\" ;;
        help) if command -v h-history >/dev/null 2>&1; then h-history; else echo \"Error: 'h-history' script not found in your PATH.\"; fi ;;
        clear) history -c && echo \"History cleared\" ;;
        edit) history -w && \${EDITOR:-vi} \"\$HISTFILE\" ;;
        uniq) history | sed 's/^[[:space:]]*[0-9]\\+[[:space:]]*[0-9-]\\{10\\} [0-9:]\\{8\\} //' | sort -u ;; # Bare unique
        top) history | sed 's/^[[:space:]]*[0-9]\\+[[:space:]]*[0-9-]\\{10\\} [0-9:]\\{8\\} //' | awk '{CMD[\$1]++} END {for (a in CMD) printf \"%5d %s\\n\", CMD[a], a;}' | sort -nr | head -10 ;; # Bare command roots top 10 - Use printf for alignment
        topn) if [[ \"\$2\" =~ ^[0-9]+$ ]]; then history | sed 's/^[[:space:]]*[0-9]\\+[[:space:]]*[0-9-]\\{10\\} [0-9:]\\{8\\} //' | awk '{CMD[\$1]++} END {for (a in CMD) printf \"%5d %s\\n\", CMD[a], a;}' | sort -nr | head -n \"\$2\"; else echo \"Invalid number\"; fi ;;
        cmds) history | sed 's/^[[:space:]]*[0-9]\\+[[:space:]]*[0-9-]\\{10\\} [0-9:]\\{8\\} //' | awk '{print \$1}' | sort | uniq -c | sort -nr | head -20 ;; # Bare command roots top 20 - uniq -c provides alignment
        root) history | sed 's/^[[:space:]]*[0-9]\\+[[:space:]]*[0-9-]\\{10\\} [0-9:]\\{8\\} //' | grep -w sudo ;; # Bare sudo commands
        backup) if [ -z \"\$2\" ]; then echo \"Please specify a filename for the backup.\"; else history > \"\$2\" && echo \"History backed up to \$2\"; fi ;;
        # --- Fallback: Treat bare number as 'n' ---
        *) [[ \"\$1\" =~ ^[0-9]+\$ ]] && history | tail -n \"\$1\" || echo \"Invalid option or number\" ;;
    esac;
    echo -e \"\\nHistory tips: !N (run cmd N), !! (run last cmd), !-N (run Nth last cmd),\"
    echo -e \"  !str (run last cmd starting w/str), !?str? (run last cmd containing str).\"
    echo -e \"Ctrl-r/s (reverse/forward history search). Note: Ctrl-s may require 'stty -ixon' to enable.\"
}

# def: Show function/alias/built-ins/scripts definitions. This must be in .bashrc to have visibility of all loaded shell functions and aliases
def() {
    if [ -z \"\$1\" ]; then
        declare -F; printf \"\\nAll defined functions ('declare -F').\\n\"
        printf \"Usage: def <name>'  - show definition of a function, alias, built-in, or script called 'name'.\\n\"
        return
    fi
    local OVERLAPS=()    # Track overlaps in an array, i.e. where the item is in more than one category
    local PAGER=\"cat\"    # Use 'cat' if 'batcat' is not available
    if command -v batcat >/dev/null 2>&1; then    # Only use 'batcat' if available
        PAGER=\"batcat -pp -l bash\"
    fi
    if declare -F \"\$1\" >/dev/null 2>&1; then    # check for a 'Function'
        declare -f \"\$1\" | \$PAGER; OVERLAPS+=(\"Function\"); echo; echo \"'\$1' is a function.\";
    fi
    if alias \"\$1\" >/dev/null 2>&1; then    # check for an 'Alias'
        alias \"\$1\" | \$PAGER; OVERLAPS+=(\"Alias\"); echo; echo \"'\$1' is an alias.\"
    fi
    if type -t \"\$1\" | grep -q \"builtin\"; then    # check for a 'built-in command'
        help \"\$1\" | \$PAGER; OVERLAPS+=(\"Built-in\"); echo; echo \"'\$1' is a built-in command.\"
    fi
    if command -v \"\$1\" >/dev/null 2>&1; then    # check for an 'external script'
        local SCRIPT_PATH=\$(command -v \"\$1\")
        if [[ -f \"\$SCRIPT_PATH\" ]]; then
            \$PAGER \"\$SCRIPT_PATH\"; OVERLAPS+=(\"Script\"); echo; echo \"'\$1' is a script, located at '\$SCRIPT_PATH'.\"
        fi
    fi
    # Display overlaps
    if [ \${#OVERLAPS[@]} -gt 1 ]; then
        joined=\$(printf \", %s\" \"\${OVERLAPS[@]}\")
        joined=\${joined:2}
        echo -e \"\\033[0;31mWarning: '\$1' has multiple types: \${joined}.\\033[0m\"    # \${OVERLAPS[*]}
    fi
    # If no matches were found
    if [ \${#OVERLAPS[@]} -eq 0 ]; then echo \"No function, alias, built-in, or script found for '\$1'.\"; fi;
}

# aliases to quickly get to various configuration scripts:
alias bashrc='vi ~/.bashrc'           # Edit .bashrc (user)
alias inputrc='vi ~/.inputrc'         # Edit .inputrc (user)
alias vimrc='vi ~/.vimrc'             # Edit .vimrc (user)
alias vimrcroot='sudo vi /etc/vim/vimrc'    # Edit vimrc (system)
alias vimrcsudo='sudo vi /etc/vim/vimrc'    # Edit vimrc (system)
config() { cd ~/.config || return; ls; }    # Jump to ~/.config
mnt() { cd /mnt || return; ls; }            # Jump to /mnt
alias sudoers='sudo visudo'                 # Edit /etc/sudoers
alias initvim='vi ~/.config/nvim/init.vim'  # Edit neovim configuration
alias nvimrc='vi ~/.config/nvim/init.vim'   # Edit neovim configuration
alias tmuxconf='vi ~/.tmux.conf'            # Edit tmux configuration
# SMB, NFS, and mount helpers
alias fstab='sudo vi /etc/fstab'            # Edit Filesystem Table
alias smb='sudo vi /etc/samba/smb.conf'     # Edit Samba configuration
alias samba='sudo vi /etc/samba/smb.conf'   # Edit Samba configuration
alias smbconf='sudo vi /etc/samba/smb.conf' # Edit Samba configuration
alias exports='sudo vi /etc/exports'        # Edit NFS exports
alias nfs-fs='sudo exportfs'                # Shows as non-existent command if run without sudo
alias nfs-fs-a='sudo exportfs -a'
alias nfs-fs-r='sudo exportfs -r'
alias nfs-fs-u='sudo exportfs -u'           # Requires directy as argument
alias nfs-fs-v='sudo exportfs -v'
alias nfs-mount='sudo showmount'            # Shows as non-existent command if run without sudo
nfs-server() { local action=\${1:-status}; sudo systemctl \"\$action\" nfs-server; }  # or start, stop, restart, enable, disable
alias nfs-mount-e='showmount -e'            # Requires <server_ip_or_hostname>
alias nfs-mount-a='showmount -a'            # Requires <server_ip_or_hostname>
alias nfs-mount-t='sudo mount -t nfs'       # Requires <server_ip_or_hostname>:/remote/path /local/mountpoint
alias unmount='sudo umount'                 # Requires path: /path/to/local/mountpoint
alias rpc='rpcinfo -p'                      # Requires <server_ip_or_hostname>
# Note also 'nfsstat'

# Simple helpers, cd.., cx, cxx, ls., ll., ifconfig, ipconfig
alias u1='cd ..';          alias cd..='u1'  # cd.. is a common typo in Linux for Windows users
alias u2='u1;U1';          alias cd..2='u2' # cd up 2 directories
alias u3='u1;u1;u1';       alias cd..3='u3' # cd up 3 directories
alias u4='u1;u1;u1;u1';    alias cd..4='u4' # cd up 4 directories
alias u5='u1;u1;u1;u1;u1'; alias cd..5='u5' # cd up 5 directories
alias cx='chmod +x'               # chmod add the execute permission
cxx() { chmod +x \$1; ./\$1; }    # chmod +x and then run \$1 immediately
alias ls.='ls -d .*'              # -d shows only the directory name, not the contents of subdirs
alias ll.='ls -ald .*'
alias ifconfig='sudo ifconfig'    # 'ifconfig' (apt install net-tools) causes 'command not found' if run without sudo
alias ipconfig='sudo ifconfig'    # Windows typo
# Create 'bat' alias for 'batcat' (apt install bacula-console-qt) unless 'bat' (Bluetooth Audio Tool) is installed
if ! command -v bat &> /dev/null && command -v batcat &> /dev/null; then alias bat='batcat'; fi   # Use bat on Debian systems

# Jump functions, cannot be in scripts as have to be dotsourced. Various for new_linux and standard locations
n()  { cd ~/new_linux || return; ls; }             # Jump to new_linux
0d() { cd ~/new_linux/0-docker || return; ls; }    # Jump to new_linux/0-docker
0g() { cd ~/new_linux/0-games || return; ls; }     # Jump to new_linux/0-games
0h() { cd ~/new_linux/0-help || return; ls; }      # Jump to new_linux/0-help
0i() { cd ~/new_linux/0-install || return; ls; }   # Jump to new_linux/0-install
0n() { cd ~/new_linux/0-notes || return; ls; }     # Jump to new_linux/0-notes
0ns() { cd ~/new_linux/0-new-system || return; ls; }  # Jump to new_linux/0-new-system
0s() { cd ~/new_linux/0-scripts || return; ls; }   # Jump to new_linux/0-scripts
v()  { cd ~/.vnc || return; ls; }                  # Jump to ~/.vnc
# Personal functions, just as example of what can be useful (though can go to a separate .bashrc-personal)
0m() { cd ~/new_linux/0-docker/0-media-stack || return; ls; }    # Jump to new_linux/0-docker/0-media-stack
0q() { cd ~/.config/media-stack/qbittorrent/qBittorrent/logs || return; ls; }    # Jump to new_linux/0-docker/0-media-stack
D()  { cd /mnt/sdc1/Downloads || return; ls; }     # Jump to my personal Downloads folder
DF() { cd /mnt/sdc1/Downloads/0\\ Films || return; ls; }  # Jump to '0 Films'
DT() { cd /mnt/sdc1/Downloads/0\\ TV || return; ls; }     # Jump to '0 TV'
DM() { cd /mnt/sdc1/Downloads/0\\ Music || return; ls; }  # Jump to '0 Music'
white() { cd ~/192.168.1.29-d || return; ls; }  # Jump to my 'WHITE' Win11 PC SMB share
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
    echo
    echo "No match for the header line in the \$bashrc_block was found in .bashrc."
    echo "So will skip full removal and move to a line by line add of \$bashrc_block."
    if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
        echo
        echo "This script is sourced, so will update the current environment after running."
        echo
    else
        echo
        echo "This script is not sourced, so to apply changes, quit and re-run as:  source ~/.bashrc"
    fi
else
    if [[ "$CLEAN_MODE" == true ]]; then
        if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
            echo
            echo "This script is sourced, so will update the current environment after running."
            echo
        else
            echo
            echo "This script is not sourced, so to apply changes, quit and re-run as:  source ~/.bashrc"
        fi

        echo "Performing cleanup: deleting all lines starting from '$first_non_empty_line' to end of .bashrc."
        sed -i "/$(printf '%s\n' "$first_non_empty_line" | sed 's/[.[\*^$]/\\&/g')/,\$d" "$BASHRC_FILE"
        echo
        echo "Removed from '$first_non_empty_line' to the end of .bashrc."
    else
        echo
        echo "CLEAN_MODE not enabled. Skipping existing block removal. Checking for individual entries..."
    fi
fi

# Always add the first non-empty line to .bashrc, regardless of removals
# echo "$first_non_empty_line" >> "$BASHRC_FILE"
# echo "Added '$first_non_empty_line' to .bashrc."

# Function to check and add lines
add_line_if_not_exists() {
    local line="$1"
    local type="$2"
    local func_name
    local is_multi_line=false

    case $type in
        alias)
            local alias_name
            alias_name=$(echo "$line" | cut -d'=' -f1 | sed 's/^[[:space:]]*alias[[:space:]]*//')

            if ! grep -qE "^[[:space:]]*alias[[:space:]]*$(printf '%s\n' "$alias_name" | sed 's/[.[\*^$]/\\&/g')[[:space:]]*=" "$BASHRC_FILE"; then
                echo "Adding alias: $line"
                echo "$line" >> "$BASHRC_FILE"
            else
                existing_line=$(grep -E "^[[:space:]]*alias[[:space:]]*$alias_name=" "$BASHRC_FILE" | head -n1)
                echo "Alias $alias_name already exists as: $existing_line"
            fi
            ;;
        export)
            local export_name
            export_name=$(echo "$line" | sed -E 's/^[[:space:]]*(export|declare -x)[[:space:]]*//; s/=.*//')
            if ! grep -qE "^[[:space:]]*(export|declare -x)[[:space:]]*$(printf '%s\n' "$export_name" | sed 's/[.[\*^$]/\\&/g')[[:space:]]*=" "$BASHRC_FILE"; then
                echo "Adding export: $line"
                echo "$line" >> "$BASHRC_FILE"
            else
                # --- CHANGE THIS MESSAGE ---
                existing_line=$(grep -E "^[[:space:]]*(export|declare -x)[[:space:]]*$export_name=" "$BASHRC_FILE" | head -n1)
                echo "Export $export_name already exists as: $existing_line"
            fi
            ;;
        comment)
            if ! grep -q "^[[:space:]]*$(printf '%s\n' "$line" | sed 's/[.[\*^$]/\\&/g')[[:space:]]*$" "$BASHRC_FILE"; then
                echo "Adding comment: $line"
                echo "$line" >> "$BASHRC_FILE"
            else
                : # Do nothing silently if comment exists
            fi
            ;;
        function)
            func_name=$(echo "$line" | cut -d' ' -f1)
            if [[ ! "$line" =~ \} ]]; then
                is_multi_line=true
            fi

            # --- Robust Existence Check for Functions ---
            # Matches: name() {, name () {, function name {, function name() {, function name () {
            if ! grep -qE "(^|[[:space:]])($(printf '%s\n' "$func_name" | sed 's/[.[\*^$]/\\&/g')[[:space:]]*\\()|(^function[[:space:]]+$(printf '%s\n' "$func_name" | sed 's/[.[\*^$]/\\&/g')[[:space:]]*[\\({])" "$BASHRC_FILE"; then
                # Function does NOT seem to exist - add it
                echo "Adding function: $func_name"
                echo "$line" >> "$BASHRC_FILE"
                if "$is_multi_line"; then
                    while IFS= read -r next_line; do
                        echo "$next_line" >> "$BASHRC_FILE"
                        if [[ "$next_line" =~ ^[[:space:]]*\}[[:space:]]*$ ]]; then break; fi
                        if [ -z "$next_line" ] && [ "$BASH_SUBSHELL" -eq 0 ]; then break; fi # Safeguard
                    done
                fi
            else
                # Function *might* exist - skip it
                echo "Function $func_name already exists. Skipping."
                if "$is_multi_line"; then
                    while IFS= read -r next_line; do
                        if [[ "$next_line" =~ ^[[:space:]]*\}[[:space:]]*$ ]]; then break; fi
                        if [ -z "$next_line" ] && [ "$BASH_SUBSHELL" -eq 0 ]; then break; fi # Safeguard
                    done
                fi
            fi
            ;;
        complete|shopt|if|fi)
            if ! grep -q "^[[:space:]]*$(printf '%s\n' "$line" | sed 's/[.[\*^$]/\\&/g')[[:space:]]*$" "$BASHRC_FILE"; then
                echo "Adding $type: $line"
                echo "$line" >> "$BASHRC_FILE"
            else
                : # Do nothing silently if the exact line exists
            fi
            ;;
        *) # other / unclassified lines
            if ! grep -q "^[[:space:]]*$(printf '%s\n' "$line" | sed 's/[.[\*^$]/\\&/g')[[:space:]]*$" "$BASHRC_FILE"; then
                echo "Adding unclassified line: $line"
                echo "$line" >> "$BASHRC_FILE"
            else
                : # Do nothing silently if the exact line exists
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
    echo
    echo "This script was sourced when run, so the environment will update now..."
    source ~/.bashrc
    echo
else
    # Script is executed
    echo
    echo "This script was not sourced, to apply changes to the current environment, run:"
    echo "   source ~/.bashrc"
    echo
fi
