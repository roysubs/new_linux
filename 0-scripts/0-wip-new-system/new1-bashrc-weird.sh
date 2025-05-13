#!/bin/bash

# new1-bashrc.sh: Update ~/.bashrc with custom configurations.
# By default, this script appends new configurations if they don't exist.
# If the -clean switch is provided, it will remove a previously added block
# (identified by a specific header line) before appending the new configurations.
# Uses 'command' prefix for critical commands to avoid alias interference when sourced.
# Ensures the block header line is explicitly added to the file.
# Processes the bashrc_block using a temporary file to potentially avoid parsing issues.
# RESTORED the add_line_if_not_exists function definition.
# CORRECTED the bashrc_block definition to remove unintended blank lines.
# REMOVED the self-sourcing command to prevent infinite loops when sourced by other scripts.

# Usage:
#   ./new1-bashrc.sh          # Appends missing configurations
#   ./new1-bashrc.sh -clean   # Removes previous block and appends configurations

BASHRC_FILE="$HOME/.bashrc"
CLEAN_MODE=false

# Check for the -clean argument
if [[ "$1" == "-clean" ]]; then
    CLEAN_MODE=true
    command echo "Clean mode enabled: Existing bashrc block will be removed before adding."
fi

# Backup ~/.bashrc before making changes
command echo "Backing up $BASHRC_FILE to $BASHRC_FILE.$(command date +'%Y-%m-%d_%H-%M-%S').bak"
command cp "$BASHRC_FILE" "$BASHRC_FILE.$(command date +'%Y-%m-%d_%H-%M-%S').bak"

# Block of text to check and add to .bashrc
# Make sure to escape " and \ in the below (change " to \" and change \n to \\n).
# Lines starting with the first non-empty line of this block will be targeted for removal in clean mode.
# Corrected to remove the leading blank line and the blank line after ####################
bashrc_block="
# new_linux definitions
####################

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
git config --global core.pager less    # Set pager for 'git'
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
# h function will not operate as a shell script as must be in .bashrc
h() {
    case \"\$1\" in
        \"\" ) # Default case when no arguments are given (show main help)
            echo -e \"History Tool. Usage: h <option> [string]\\n  a|an|ad|ab    show all history (a full, an numbers only, ad datetime only, ab bare commands)\\n  f|fn|fd|fb    find string (f full, fn numbers only, fd datetime only, fb bare commands)\\n  n <num>      Show last N history entries (full)\\n  help          Show extended help from 'h-history' script\\n  clear         Clear the history\\n  edit          Edit the history file in your editor\\n  uniq          Show unique history entries (bare)\\n  top           Show top 10 most frequent commands (bare roots)\\n  cmds          Show top 20 most frequent command roots (bare)\\n  root          Show commands run with sudo (bare)\" ;; # Removed 'r' and trailing \\n
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
        cmds) history | sed 's/^[[:space:]]*[0-9]\\+[[:space:]]*[0-9-]\\{10\\} [0-9:]\\{8\\} //' | awk '{print \$1}' | sort | uniq -c | sort -nr | head -20 ;; # Bare command roots top 20 - uniq -c provides alignment
        root) history | sed 's/^[[:space:]]*[0-9]\\+[[:space:]]*[0-9-]\\{10\\} [0-9:]\\{8\\} //' | grep -w sudo ;; # Bare sudo commands

        # --- Fallback: Treat bare number as 'n' ---
        *) [[ \"\$1\" =~ ^[0-9]+\$ ]] && history | tail -n \"\$1\" || echo \"Invalid option or number\" ;;
    esac;
    echo -e \"\\nHistory tips: !N (run cmd N), !! (run last cmd), !-N (run Nth last cmd),\"
    echo -e \"  !str (run last cmd starting w/str), !?str? (run last cmd containing str).\"
    echo -e \"Ctrl-r/s (reverse/forward incr type). Note: may need 'stty -ixon' to enable Ctrl-s.\"
}

# aliases to quickly get to various configuration scripts:
alias bashrc='vi ~/.bashrc'           # Edit .bashrc (user)
alias inputrc='vi ~/.inputrc'         # Edit .inputrc (user)
alias vimrc='vi ~/.vimrc'             # Edit .vimrc (user)
alias vimrcroot='sudo vi /etc/vim/vimrc'    # Edit vimrc (system)
alias vimrcsudo='sudo vi /etc/vim/vimrc'    # Edit vimrc (system)
0config() { cd ~/.config || return; ls; }    # Jump to ~/.config
0vnc() { cd ~/.vnc || return; ls; }          # Jump to ~/.vnc
alias initvim='vi ~/.config/nvim/init.vim'  # Edit neovim configuration
alias nvimrc='vi ~/.config/nvim/init.vim'   # Edit neovim configuration
alias smb='sudo vi /etc/samba/smb.conf'     # Edit Samba configuration
alias samba='sudo vi /etc/samba/smb.conf'   # Edit Samba configuration
alias smbconf='sudo vi /etc/samba/smb.conf' # Edit Samba configuration
alias fstab='sudo vi /etc/fstab'          # Edit Filesystem Table
alias exports='sudo vi /etc/exports'        # Edit NFS exports
alias sudoers='sudo visudo'                 # Edit /etc/sudoers
alias tmuxconf='vi ~/.tmux.conf'            # Edit tmux configuration
# fs: useful filesystem output (filtered lsblk + /etc/fstab)
# 1 RAM disks (/dev/ram*), 7 Loop devices (/dev/loop*), 11 CD-ROM (/dev/sr0)
# 179 MMC/SD cards (optional), 252 Device mapper (optional, LVM, crypt), 253 Zram (swap compression)
# NR==1  : keep the first line (the header)
# NF > 1 : keep rows with more than 1 field (so, real partitions with data, e.g. /dev/sda2 was Extended partition, so just holds other partitions)
# Optional | grep -v -E \"^/dev/sd[a-z]\\s*$\"'    # | grep -E \"/dev/.+[0-9]+\\b\" | awk \"NF > 1\"'
# alias fs='awk '/^# <file/ {print; next} /^#/ {next} {print | \"sort\"}' /etc/fstab; echo; lsblk -o NAME,FSTYPE,FSSIZE,FSAVAIL,FSUSED,FSUSE%,UUID,MOUNTPOINT -lp -e 1,7,11,253 | awk \"NR==1 || NF > 1\"'
alias fs=\"awk '/^# <file/ {print; next} /^#/ {next} {print | \\\"sort\\\"}' /etc/fstab; echo; lsblk -o NAME,FSTYPE,FSSIZE,FSAVAIL,FSUSED,FSUSE%,UUID,MOUNTPOINT -lp -e 1,7,11,253 | awk 'NR==1 || NF > 1'\"

# Simple helpers, cd.., cx, cxx, ls., ll., ifconfig, ipconfig
alias cd..='cd ..'            # Common typo for Windows users (cd.. is normally an error in Linux)
alias cd...='cd..;cd..'              # cd up 2 directories
alias cd....='cd..;cd..;cd..'            # cd up 3 directories
alias cd.....='cd..;cd..;cd..;cd..'      # cd up 4 directories
alias cd......='cd..;cd..;cd..;cd..;cd..' # cd up 5 directories
alias u1='cd..'              # cd up 1 directory
alias u2='cd..;cd..'         # cd up 2 directories
alias u3='cd..;cd..;cd..'    # cd up 3 directories
alias u4='cd..;cd..;cd..;cd..' # cd up 4 directories
alias u5='cd..;cd..;cd..;cd..;cd..' # cd up 4 directories
alias cx='chmod +x'            # chmod add the execute permission
cxx() { chmod +x \$1; ./\$1; }     # add execute to \$1 and also run it immediately
alias ls.='ls -d .*'          # -d shows only the directory, not the contents (of .config etc)
alias ll.='ls -ald .*'
alias ifconfig='sudo ifconfig'    # 'ifconfig' has 'command not found' if run without sudo (apt install net-tools)
alias ipconfig='sudo ifconfig'    # Windows typo

# This function must be in .bashrc to have visibility of all loaded shell functions and aliases
def() {
    if [ -z \"\$1\" ]; then
        declare -F; printf \"\\nAll defined functions ('declare -F').\\n\"
        printf \"'def <name>' to show definitions of functions, aliases, built-ins, and scripts.\\n\\n\"
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

# Jump functions for new_linux and  (ideally, should be in a separate sourced script.
. ~/.bashrc-
n()  { cd ~/new_linux || return; ls; }            # Jump to new_linux
0d() { cd ~/new_linux/0-docker || return; ls; }    # Jump to new_linux/0-docker
0g() { cd ~/new_linux/0-games || return; ls; }     # Jump to new_linux/0-games
0h() { cd ~/new_linux/0-help || return; ls; }      # Jump to new_linux/0-help
0i() { cd ~/new_linux/0-install || return; ls; }  # Jump to new_linux/0-install
0n() { cd ~/new_linux/0-notes || return; ls; }     # Jump to new_linux/0-notes
0ns() { cd ~/new_linux/0-new-system || return; ls; }  # Jump to new_linux/0-new-system
0s() { cd ~/new_linux/0-scripts || return; ls; }  # Jump to new_linux/0-scripts
v()  { cd ~/.vnc || return; ls; }                  # Jump to ~/.vnc
# These a
D()  { cd /mnt/sdc1/Downloads || return; ls; }    # Jump to my personal Downloads folder
DF() { cd /mnt/sdc1/Downloads/0\\ Films || return; ls; }  # Jump to 0 Films
DT() { cd /mnt/sdc1/Downloads/0\\ TV || return; ls; }      # Jump to 0 TV
DM() { cd /mnt/sdc1/Downloads/0\\ Music || return; ls; }  # Jump to 0 Music
white() { cd ~/192.168.1.29-d || return; ls; }  # Jump to my 'WHITE' Win11 PC SMB share

"

# Capture the first non-empty line of $bashrc_block, this is the header line
# This line is used to identify the start of the block for removal in clean mode.
first_non_empty_line=$(command echo "$bashrc_block" | command sed -n '/[^[:space:]]/s/^[[:space:]]*//p' | command head -n 1)

# Ensure the variable is not empty
if [[ -z "$first_non_empty_line" ]]; then
    command echo "Error: No valid content found in bashrc_block. Cannot identify block header for clean mode."
    # Continue to append mode logic anyway, but clean mode won't work
    CLEAN_MODE=false
fi

# --- Clean Mode Logic ---
if $CLEAN_MODE; then
    if command grep -Fxq "$first_non_empty_line" "$BASHRC_FILE"; then
        command echo
        command echo "Found existing block starting with '$first_non_empty_line'."
        command echo "Removing lines from this header to the end of $BASHRC_FILE."
        # Delete from the found line to the end of the file
        # Escape special characters in the header for sed
        escaped_header=$(command printf '%s\n' "$first_non_empty_line" | command sed 's/[.[\*^$]/\\&/g')
        command sed -i "/$escaped_header/,\$d" "$BASHRC_FILE"
        command echo "Removal complete."
    else
        command echo
        command echo "Did not find existing block starting with '$first_non_empty_line' in $BASHRC_FILE."
        command echo "No lines removed."
    fi
fi
# --- End Clean Mode Logic ---

# Explicitly add the header line to the bashrc file.
# This ensures it exists for future clean operations.
# We append it here regardless of clean mode. If it exists, grep -Fxq in add_line_if_not_exists
# will prevent duplicates when processing the block line-by-line, although the add_line_if_not_exists
# function also has a specific check to skip the header line itself.
# Appending here guarantees it's added if missing after a non-clean run or after a clean run.
# Check if the header line already exists before adding it explicitly here, to avoid duplicates
# when not in clean mode and the header is already present.
if ! command grep -Fxq "$first_non_empty_line" "$BASHRC_FILE"; then
    command echo "$first_non_empty_line" >> "$BASHRC_FILE"
    # command echo "Added header line '$first_non_empty_line' to $BASHRC_FILE." # Optional debug
else
    # command echo "Header line '$first_non_empty_line' already exists in $BASHRC_FILE." # Optional debug
    : # No-op if header exists
fi


command echo # Add a newline for separation
command echo "Appending missing configurations to $BASHRC_FILE..."

# Function to check and add lines if they don't exist
# This function is used in both default (append) and clean modes (after cleaning).
add_line_if_not_exists() {
    local line="$1"
    local type="$2"

    # Skip adding the header line itself here, it will be handled implicitly
    # by the loop adding the whole block if needed.
    # This prevents adding the header multiple times if not in clean mode
    # and the header already exists but some lines below it are missing.
    if [[ "$line" == "$first_non_empty_line" ]]; then
      # command echo "Skipping adding header line via line-by-line check." # Optional debug
      return
    fi

    # Handle blank lines separately to ensure they are added
    if [[ -z "$line" ]]; then
        # Check if the previous line in the block was also blank. Avoid excessive blank lines.
        # This is a heuristic and might not be perfect for all cases.
        # A more robust approach would be to process the block into an array first.
        # For simplicity, we'll just add blank lines if they aren't already present
        # immediately before the position they would be added.
        # This is tricky with line-by-line append logic.
        # A simpler approach is to just add it and rely on the final sed to clean up blank lines.
        # Let's just add it and let the final sed handle cleanup.
         command echo "$line" >> "$BASHRC_FILE"
         # command echo "Added blank line." # Optional debug
         return
    fi


    # For non-blank lines, check if they already exist exactly
    if ! command grep -Fxq "$line" "$BASHRC_FILE"; then
        # command echo "Adding $type: $line" # Optional debug
        command echo "$line" >> "$BASHRC_FILE"
    # else
        # command echo "Skipping existing $type: $line" # Optional debug
    fi
}


# --- Process bashrc_block using a temporary file ---
TEMP_BASHRC_BLOCK=$(command mktemp)
command echo "$bashrc_block" > "$TEMP_BASHRC_BLOCK"

# Process each line in the temporary file and add if not already present
# This loop runs regardless of clean mode. In clean mode, it populates the file
# after the old block was removed (and the header re-added). In default mode, it appends missing lines.
while IFS= read -r line; do
    # Determine line type (basic heuristic) - Note: Function definition is handled by the function itself
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
        # This is a simple check for function definition start
        # Multi-line functions are handled line-by-line by add_line_if_exists
        # This is a potential weakness if parts of the function body exist but not the header.
        # A more robust approach would parse the block into logical units first.
        # Sticking to line-by-line for minimal changes as requested.
        add_line_if_not_exists "$line" "function_start"
    elif [[ -z "$line" ]]; then
        # Handle blank lines - add them if they don't exist
        add_line_if_not_exists "$line" "blank"
    else
        add_line_if_not_exists "$line" "other"
    fi
done < "$TEMP_BASHRC_BLOCK" # Read from the temporary file

# Clean up the temporary file
command rm "$TEMP_BASHRC_BLOCK"
# --- End processing bashrc_block using temporary file ---


# Remove trailing blank lines that might have been introduced
# This sed command removes one or more blank lines from the end of the file.
command sed -i ':a; N; $!ba; s/\n[[:space:]]*\n*$//' "$BASHRC_FILE"

command echo
command echo "Finished updating $BASHRC_FILE."

# Provide instructions on how to apply changes
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    # Script is sourced
    # REMOVED: command source "$BASHRC_FILE" to prevent infinite loop
    command echo "This script was sourced when run. To apply changes, manually source ~/.bashrc or start a new terminal session."
else
    # Script is executed
    command echo "This script was executed, not sourced."
    command echo "To apply changes to the current environment, run:"
    command echo "    source ~/.bashrc"
fi
command echo

