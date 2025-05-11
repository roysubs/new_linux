#!/bin/bash
#
# Script: cls
# Description: Clears the screen but retains scrollback buffer.
# Based on: alias cls='clear -x'
#
clear -x

#!/bin/bash
#
# Script: hh
# Description: Displays bash history formatted with '#' for easy copying into documentation.
# Based on: hh() { history "$@" | awk '{$1=$2=$3=""; print $0}' | sed 's/^[ \t]*/# /;s/[ \t]*$//'; }
# Dependencies: history, awk, sed
#
# Usage: hh [history options]
# Example: hh 10  # Shows last 10 commands formatted
#
history "$@" | awk '{$1=$2=$3=""; print $0}' | sed 's/^[ \t]*/# /;s/[ \t]*$//'

#!/bin/bash
#
# Script: h0
# Description: Displays bash history without the timestamp.
# Based on: alias h0='HISTTIMEFORMAT= history'
# Dependencies: history
#
# Usage: h0 [history options]
# Example: h0 5 # Shows last 5 commands without timestamps
#
HISTTIMEFORMAT= history "$@"

#!/bin/bash
#
# Script: mountt
# Description: Lists mounted file systems in a formatted table.
# Based on: alias mountt='mount | column -t'
# Dependencies: mount, column
#
# Usage: mountt
#
mount | column -t

#!/bin/bash
#
# Script: psg
# Description: Searches processes by name, showing full listing and including WCHAN headers.
# Based on: alias psg='ps -Helf | grep -v $$ | grep -i -e WCHAN -e'
# Dependencies: ps, grep
#
# Usage: psg <search_string>
# Example: psg nginx
#
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <search_string>"
    exit 1
fi
ps -Helf | grep -v "$$" | grep -i -e WCHAN -e "$1"

#!/bin/bash
#
# Script: tree-all
# Description: Simulates 'tree .' output for files and directories using find and sed.
# Note: Can be slow on large directories compared to the actual 'tree' command.
# Based on: alias tree-all="find . -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'"
# Dependencies: find, sed
#
# Usage: tree-all [start_directory]
# Example: tree-all /etc
#
start_dir=${1:-.}
find "$start_dir" -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g' -e 's;____|; |;g'

#!/bin/bash
#
# Script: tree-dir
# Description: Simulates 'tree .' output showing only directories using ls and sed.
# Note: Relies on ls output and grep, potentially less reliable than 'find -type d'.
# Based on: alias tree-dir="ls -R | grep :*/ | grep ":$" | sed -e 's/:$//' -e 's/[^-][^/]*//--/g' -e 's/^/    /' -e 's/-/|/'"
# Dependencies: ls, grep, sed
#
# Usage: tree-dir [start_directory]
# Example: tree-dir .
#
start_dir=${1:-.}
ls -R "$start_dir" | grep ":*/" | grep ":$" | sed -e 's/:$//' -e 's/[^-][^/]*//--/g' -e 's/^/    /' -e 's/-/|/'

#!/bin/bash
#
# Script: brokenlinks
# Description: Finds broken symbolic links starting from the current directory.
# Based on: alias brokenlinks='find . -xtype l -printf "%p -> %ln"'
# Dependencies: find
#
# Usage: brokenlinks [start_directory]
# Example: brokenlinks /opt
#
start_dir=${1:-.}
find "$start_dir" -xtype l -printf "%p -> %ln\n" 2>/dev/null

#!/bin/bash
#
# Script: meminfo
# Description: Displays key memory information (Mem, Cache, Swap) from /proc/meminfo.
# Based on: alias meminfo='\egrep "Mem|Cache|Swap" /proc/meminfo'
# Dependencies: egrep (or grep)
#
# Usage: meminfo
#
egrep "Mem|Cache|Swap" /proc/meminfo

#!/bin/bash
#
# Script: pbcopy
# Description: Copies standard input to the X clipboard.
# Based on: alias pbcopy='xclip -selection clipboard' or 'xsel --clipboard --input'
# Dependencies: xclip (or xsel)
#
# Usage: some_command | pbcopy
# Example: cat myfile.txt | pbcopy
#
if type xclip >/dev/null 2>&1; then
    xclip -selection clipboard
elif type xsel >/dev/null 2>&1; then
    xsel --clipboard --input
else
    echo "Error: Neither xclip nor xsel found. Please install one of them." >&2
    exit 1
fi

#!/bin/bash
#
# Script: pbpaste
# Description: Pastes content from the X clipboard to standard output.
# Based on: alias pbpaste='xclip -selection clipboard -o' or 'xsel --clipboard --output'
# Dependencies: xclip (or xsel)
#
# Usage: pbpaste > myfile.txt
# Example: pbpaste | grep something
#
if type xclip >/dev/null 2>&1; then
    xclip -selection clipboard -o
elif type xsel >/dev/null 2>&1; then
    xsel --clipboard --output
else
    echo "Error: Neither xclip nor xsel found. Please install one of them." >&2
    exit 1
fi

#!/bin/bash
#
# Script: hogs
# Description: Lists processes sorted by CPU usage (highest first).
# Based on: alias hogs='ps uxga | sort --key=3.1 -n'
# Dependencies: ps, sort
#
# Usage: hogs
#
ps uxga | sort --key=3.1 -n

#!/bin/bash
#
# Script: myusb
# Description: Identifies device assignments (like sdX) for connected USB drives.
# Based on: myusb() { ... }
# Dependencies: find, readlink, cut, echo
#
# Usage: myusb
#
myusb() {
    local usb_array=()
    # Use null delimiter with find and xargs -0 for safety with spaces/special characters
    while IFS= read -r -d $'\0'; do
        usb_array+=("$REPLY")
    done < <(find /dev/disk/by-path/ -type l -iname '*usb*scsi*' -not -iname '*usb*scsi*part*' -print0 | xargs -0 -I {} readlink -f {} | cut -c 8 --output-delimiter=$'\0')

    if [ ${#usb_array[@]} -eq 0 ]; then
        echo "No USB drives found."
    else
        echo "Found USB drive(s) assigned to:"
        for usb in "${usb_array[@]}"; do
            echo "/dev/sd$usb"
        done
    fi
}

myusb

#!/bin/bash
#
# Script: countdown
# Description: Simple command-line countdown timer.
# Based on: countdown() { ... }
# Dependencies: sleep, printf, echo
#
# Usage: countdown <seconds>
# Example: countdown 10 # Counts down from 10
#
countdown() {
    if [ "$#" -ne 1 ] || ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "Usage: $0 <seconds>"
        echo "Provide the total number of seconds to count down from."
        return 1
    fi

    local total=$1
    echo "Starting countdown for $total seconds..."
    for ((i=total; i>0; i--)); do
        sleep 1
        printf "Time remaining: %d secs\r" "$i"
    done
    echo -e "\nTime's up!"
    echo -e "\a" # Audible alert
}

countdown "$@"

#!/bin/bash
#
# Script: lsec
# Description: Lists files/directories with detailed information including ls-style and octal permissions, owner, group, size, and timestamp, using 'stat'.
# Based on: lsec() { ... }
# Dependencies: stat, awk, column
#
# Usage: lsec [files or directories...]
# Example: lsec .
# Example: lsec myfile.txt mydir/
#
lsec() {
    local args='.' # Default to current directory if no args
    if [ "$#" -gt 0 ]; then
        args="$@"
    fi

    # Check if 'column' is available, required for pretty output
    if ! type column >/dev/null 2>&1; then
        echo "Error: 'column' command not found. Please install it (e.g., 'apt install bsdmainutils' or 'yum install util-linux')." >&2
        # Fallback to just printing tab-separated if column is missing
        stat --printf="%A\t%a\t%h\t%U\t%G\t%s\t%.19y\t%n\n" $args 2>/dev/null || { echo "Error running stat on arguments."; exit 1; }
        return 1
    fi

    # Using awk for dynamic width calculation and column for final formatting
    # Exclude errors from stat gracefully if possible
    stat --printf="%A\t%a\t%h\t%U\t%G\t%s\t%.19y\t%n\n" $args 2>/dev/null |
    awk 'BEGIN { FS = "\t"; OFS = "\t" }
         {
           for (i=1; i<=NF; i++) {
             vals[NR,i] = $i;
             # Calculate max width for each column, handle numbers for right alignment
             len = length($i);
             if (!(i in width) || len > width[i]) width[i] = len;
             if ($i ~ /^[0-9]+$/) align[i] = ""; else align[i] = "-"; # Align numbers right, others left
           }
         }
         END {
           # Print header (optional, but useful - manually define or extract from names)
           # printf "%-10s %-5s %-5s %-8s %-8s %8s %20s %s\n", "Perm(ls)", "Perm(Oct)", "Links", "Owner", "Group", "Size", "Modified", "Name"; # Example header
           for (n=1; n<=NR; n++) {
             line = "";
             for (i=1; i<=NF; i++) {
               # Format based on calculated width and alignment
               printf "%" align[i] width[i] "s%s", vals[n,i], (i == NF ? "" : OFS);
             }
             print "";
           }
         }' | column -t

    # Note: The original script had an Alpine specific simpler version using just column -t.
    # This version attempts to be more generally formatted using awk first, then column.
    # For simplicity in a standalone script, column -t directly might suffice for many cases:
    # stat --printf="%A\t%a\t%h\t%U\t%G\t%s\t%.19y\t%n\n" $args 2>/dev/null | column -t
}

lsec "$@"

#!/bin/bash
#
# Script: lperm
# Description: Lists files/directories showing ls-style and octal permissions using 'stat'.
# Based on: lperm() { ... }
# Dependencies: stat, column
#
# Usage: lperm [files or directories...]
# Example: lperm my_script.sh
#
lperm() {
    local args='.' # Default to current directory if no args
    if [ "$#" -gt 0 ]; then
        args="$@"
    fi

    if ! type column >/dev/null 2>&1; then
        echo "Error: 'column' command not found. Please install it (e.g., 'apt install bsdmainutils' or 'yum install util-linux')." >&2
        stat --printf="%A\t%a\t%n\n" $args 2>/dev/null || { echo "Error running stat on arguments."; exit 1; }
        return 1
    fi

    # Print permissions (%A for ls format, %a for octal) and name (%n)
    stat --printf="%A\t%a\t%n\n" $args 2>/dev/null | column -t
}

lperm "$@"

#!/bin/bash
#
# Script: sanitize
# Description: Recursively sets standard file/directory permissions:
#              Owner: read, write, execute (for directories or if executable)
#              Group: read, execute (for directories or if executable)
#              Others: no permissions
# Based on: sanitize() { chmod -R u=rwX,g=rX,o= "$@" ;}
# Dependencies: chmod
#
# Usage: sanitize <directory_or_file...>
# Example: sanitize mydir/ myfile.txt
#
sanitize() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: $0 <directory_or_file...>"
        echo "Sets standard permissions recursively on provided paths."
        echo "Owner: rwX, Group: rX, Others: no access."
        return 1
    fi

    # Use -v for verbose output to show what's being changed
    chmod -R -v u=rwX,g=rX,o= "$@"
}

sanitize "$@"

#!/bin/bash
#
# Script: uncolor
# Description: Removes ANSI color and control characters from standard input.
# Based on: uncolor() { perl -pe 's/\e([^\[\]]|\[.*?[a-zA-Z]|\].*?\a)//g' | col -b; }
# Dependencies: perl, col
#
# Usage: command_with_color_output | uncolor
# Example: ls --color=always | uncolor
#
uncolor() {
    if ! type perl >/dev/null 2>&1; then
        echo "Error: 'perl' command not found. Cannot remove colors." >&2
        cat # Just pass through if perl is missing
        return 1
    fi
     if ! type col >/dev/null 2>&1; then
        echo "Warning: 'col' command not found. Output might contain some lingering control characters." >&2
        perl -pe 's/\e([^\[\]]|\[.*?[a-zA-Z]|\].*?\a)//g' # Run perl only
        return 0 # Not a fatal error
    fi
    perl -pe 's/\e([^\[\]]|\[.*?[a-zA-Z]|\].*?\a)//g' | col -b
}

# Note: This function is often used as a helper for other scripts that search shell functions/aliases.
# It reads from stdin, so it's useful in pipelines.

#!/bin/bash
#
# Script: aaa
# Description: Searches and lists aliases in the current shell environment that match a string.
# Note: As a standalone script, this only lists aliases defined *within this script's subshell*,
# NOT the aliases in the user's interactive shell where you might typically use it.
# This function is most useful when sourced into your interactive shell.
# Based on: aaa() { ... }
# Dependencies: alias, sed, grep, bat (optional), cat
#
# Usage: Source this file and then run: aaa [search_string]
# Or as a script (limited use): aaa [search_string]
#
aaa() {
    local PAGER='cat'
    if type bat > /dev/null 2>&1; then
        # Use bat if available for syntax highlighting
        PAGER='bat -pp -l python' # Python style is often okay for alias output
    fi

    if [ -z "$1" ]; then
        # List all aliases if no argument
        echo "Listing all aliases:"
        alias | $PAGER
        echo ""
    else
        # Search for aliases containing the string
        echo "Listing aliases containing '$1':"
        # sed removes the "alias " prefix
        # grep searches for the string
        alias | sed 's/^alias //g' | grep "$1" | $PAGER
        echo -e "\nAbove shows all aliases that contain the string '$1'"
    fi
}

# This script is best used by sourcing its definition into your interactive shell.
# If run directly, it will only show aliases defined *before* this function in this script, or none.
# aaa "$@" # Uncomment this line to run when executed, but be aware of limitations.

#!/bin/bash
#
# Script: fff
# Description: Searches and lists functions in the current shell environment that match a string.
# Note: As a standalone script, this only lists functions defined *within this script's subshell*,
# NOT the functions in the user's interactive shell where you might typically use it.
# This function is most useful when sourced into your interactive shell.
# Based on: fff() { ... }
# Dependencies: declare, awk, bat (optional), cat, uncolor (should be defined or available)
#
# Usage: Source this file and then run: fff [search_string]
# Or as a script (limited use): fff [search_string]
#
# Include the uncolor function as it's used by aaff which often calls fff/aaa
uncolor() {
    if ! type perl >/dev/null 2>&1; then cat; return 1; fi
    if ! type col >/dev/null 2>&1; then perl -pe 's/\e([^\[\]]|\[.*?[a-zA-Z]|\].*?\a)//g'; return 0; fi
    perl -pe 's/\e([^\[\]]|\[.*?[a-zA-Z]|\].*?\a)//g' | col -b
}


fff() {
    local PAGER='cat'
    if type bat > /dev/null 2>&1; then
        # Use bat if available for syntax highlighting
        PAGER='bat -pp -l bash'
    fi

    if [ -z "$1" ]; then
        # List all function names if no argument
        echo "Listing all function names:"
        declare -F | awk '{print $3}' | $PAGER
        echo ""
    else
        # Search for function definitions containing the string
        echo "Listing function definitions containing '$1':"
        # awk logic to print function definitions if they contain the search string
        # Assumes function definitions are multi-line starting with name() { ... }
        declare -f | awk -v srch="$1" '
            # New function definition starts after "}" or at start of output
            NF==2 && $2=="()" {
                if (m) { print buf } # Print previous function definition if it matched
                buf=""; m=0          # Reset buffer and match flag
            }
            # Check if current line contains the search string (case-sensitive here, unlike original grep -i?)
            # Use index($0,srch) or tolower($0) ~ tolower(srch) for case-insensitivity if needed
            index($0,srch) { m=1 } # Set match flag if string found in current line or previous lines of function def
            {
                buf = buf (buf=="" ? "" : ORS) $0 # Append current line to buffer
            }
            END {
                if (m) print buf # Print the last function definition if it matched
            }
        ' | $PAGER
        echo -e "\nAbove shows all functions that contain the string '$1'"
    fi
}
# This script is best used by sourcing its definition into your interactive shell.
# If run directly, it will only show functions defined *before* this function in this script, or none.
# fff "$@" # Uncomment this line to run when executed, but be aware of limitations.


#!/bin/bash
#
# Script: aaff
# Description: Searches and lists both aliases and functions in the current shell environment that match a string.
# Note: As a standalone script, this only lists aliases/functions defined *within this script's subshell*,
# NOT the aliases/functions in the user's interactive shell where you might typically use it.
# This function is most useful when sourced into your interactive shell.
# Based on: aaff() { ... }
# Dependencies: fff (should be defined or available), aaa (should be defined or available), uncolor (should be defined or available), grep
#
# Usage: Source this file and then run: aaff [search_string]
# Or as a script (limited use): aaff [search_string]
#
# Include dependencies: uncolor, aaa, fff (basic versions)
uncolor() {
    if ! type perl >/dev/null 2>&1; then cat; return 1; fi
    if ! type col >/dev/null 2>&1; then perl -pe 's/\e([^\[\]]|\[.*?[a-zA-Z]|\].*?\a)//g'; return 0; fi
    perl -pe 's/\e([^\[\]]|\[.*?[a-zA-Z]|\].*?\a)//g' | col -b
}

aaa() {
    local PAGER='cat'; if type bat >/dev/null 2>&1; then PAGER='bat -pp -l python'; fi
    if [ -z "$1" ]; then alias | $PAGER; else alias | sed 's/^alias //g' | grep "$1" | $PAGER; fi
    echo -e "\nAbove shows all aliases that contain the string '$1'"
}

fff() {
    local PAGER='cat'; if type bat >/dev/null 2>&1; then PAGER='bat -pp -l bash'; fi
    if [ -z "$1" ]; then declare -F | awk '{print $3}' | $PAGER; else declare -f | awk -v srch="$1" 'NF==2 && $2=="()"{if (m) print buf; buf=""; m=0} index($0,srch){m=1} {buf=buf ORS $0} END{if (m) print buf}' | $PAGER; fi
    echo -e "\nAbove shows all functions that contain the string '$1'"
}

aaff() {
    if [ -z "$1" ]; then
        echo "Usage: aaff <search_string>"
        echo "Searches for aliases and functions containing the specified string."
        return 1
    fi

    echo -e "\e[1;37m\nAll functions that contain '$1':\n_________________________\n\e[0m"
    # Use the fff function to search, pipe to uncolor and grep for just the function names ending in ()
    fff "$1" | uncolor | grep "()" | uncolor | grep -v "^[[:space:]]"
    echo -e "\e[1;37m\n\nAll aliases that contain '$1':\n_________________________\n\e[0m"
    # Use the aaa function to search for aliases
    aaa "$1"
}

# This script is best used by sourcing its definition into your interactive shell.
# If run directly, it will only see aliases/functions defined *before* this function in this script, or none.
# aaff "$@" # Uncomment this line to run when executed, but be aware of limitations.


#!/bin/bash
#
# Script: myfunctions
# Description: Lists the names of user-defined functions in the current shell environment (excluding names starting with '_').
# Note: As a standalone script, this only lists functions defined *within this script's subshell*,
# NOT the functions in the user's interactive shell where you might typically use it.
# This function is most useful when sourced into your interactive shell.
# Based on: myfunctions() { declare -F | awk '{print $NF}' | sort | egrep -v "^_"; }
# Dependencies: declare, awk, sort, egrep
#
# Usage: Source this file and then run: myfunctions
# Or as a script (limited use): myfunctions
#
myfunctions() {
    # declare -F lists function names and where they were defined
    # awk '{print $NF}' extracts the function name (last field)
    # sort sorts the names alphabetically
    # egrep -v "^_" excludes names starting with an underscore (often internal/private functions)
    declare -F | awk '{print $NF}' | sort | egrep -v "^_"
}
# This script is best used by sourcing its definition into your interactive shell.
# If run directly, it will only see functions defined *before* this function in this script, or none.
# myfunctions # Uncomment this line to run when executed, but be aware of limitations.


#!/bin/bash
#
# Script: set-ls
# Description: Prints bash alias definitions for various 'ls' commands (ll, la, lt, etc.).
# To use these aliases, you must EVAL or SOURCE the output of this script in your shell.
# Running this script directly will only define the aliases in its own subshell, which immediately exits.
# Based on: set-ls() { ... } (contains alias definitions)
# Dependencies: echo
#
# Usage: eval "$(set-ls)"
# Or: source set-ls.sh
#
echo "alias ls='\ls --color=always --group-directories-first'"
echo "alias la='ls -AFh'"
echo "alias ll='ls -lh'"
echo "alias lla='ls -AFhl'"
echo "alias lll='ls -AFhl'"
echo "alias L='ls --human-readable --size -1 -S --classify'"
echo "alias ls.='ls -d .*'"
echo "alias l.='ls -d .*'"
echo "alias ll.='ls -dl .*'"
echo "alias lld='ls -FlAd | grep /$'"
echo "alias llfd='find \. -maxdepth 1 -type d'"
echo "alias lldt='tree . -faild -L 1'"
echo "alias llt='tree . -fail --du -h'"
echo "alias llf='ls -FlA | grep -v "/"'"
echo "alias llv='vdir'"
echo "alias ldot=\"ls -ld .??*\""
echo "alias lnox=\"find . -maxdepth 1 -type f ! -executable\""
echo "alias lx=\"find . -maxdepth 1 -type f -executable\""
echo "alias lxext='ll *.sh *.csh *.ksh *.c *.cpp *.py *.jar *.exe *.bat *.cmd *.com *.js *.vbs *.wsh *.ahk *.ps1 *.psm1 2> /dev/null'"
echo "alias lext='ls -Fla | egrep \"\\.\""
echo "alias lnoext='ls -Fla | egrep -v \"\\.\""
echo "alias lsp='find . -maxdepth 1 -perm -111 -type f'"
# Note: lsum alias involves awk logic, might be better as a function or separate script if complex.
# For simplicity, sticking to simpler alias definitions here.
echo "alias lm='ls -Am'; alias lcsv='lm'"
echo "alias lsz='ls -lAshSr'; alias lsize='lsz'"
echo "alias lt='ls -lAth'; alias ltime='lt'; alias ldate='lt'; alias lst='lt'"
echo "alias sl='ls'"
# chmod aliases - these are simple wrappers, printing them out is less useful than just defining them.
# If you want these as standalone scripts, each chmod alias would be its own small script file.
# e.g., a script 'chmod644': #!/bin/bash; echo "644 -rw-r--r-- (Owner rw-, Group r--, Other r--)"; chmod 644 "$@"


#!/bin/bash
#
# Script: set-ls-to-exa
# Description: Prints bash alias definitions for 'ls' commands using 'exa' (if available).
# To use these aliases, you must EVAL or SOURCE the output of this script in your shell.
# Running this script directly will only define the aliases in its own subshell, which immediately exits.
# Requires the 'exa' command to be installed.
# Based on: set-ls-to-exa() { ... } (contains alias definitions)
# Dependencies: echo, exa (for the aliases to work)
#
# Usage: eval "$(set-ls-to-exa)"
# Or: source set-ls-to-exa.sh
# Check if exa is available before printing definitions
if type exa >/dev/null 2>&1; then
    echo "# exa found, printing exa-based ls aliases"
    echo "alias ls='\exa --color=always --group-directories-first'"
    echo "alias la='ls -a'"
    echo "alias ll='ls -lh'"
    echo "alias lla='ls -la'"
    echo "alias lt='ls -las modified'"
    echo "alias lg='ls -lGh'"
    echo "alias ltree='ls -aT'"
    echo "alias exatree='ls -aT'"
    echo "alias l.='ls -a | egrep \"^\\.\""
else
    echo "# exa not found. Not setting exa-based ls aliases." >&2
    echo "# To use these, install exa (e.g. 'sudo apt install exa')" >&2
fi

#!/bin/bash
#
# Script: hx
# Description: Displays bash history in a raw, executable format, based on the 'hh' output.
# Based on: hx() { hh | sed 's/^#\ //'; }
# Dependencies: hh (should be defined or available), sed
#
# Usage: hx [history options for hh]
# Example: hx 10 # Shows last 10 commands as raw commands
#
# Include the hh function as it's a dependency
hh() { history "$@" | awk '{$1=$2=$3=""; print $0}' | sed 's/^[ \t]*/# /;s/[ \t]*$//'; }

hx() {
    # Call hh and then remove the leading '# ' added by hh
    hh "$@" | sed 's/^#\ //'
}

hx "$@"


#!/bin/bash
#
# Script: uncolor
# Description: Removes ANSI color and control characters from standard input.
# Based on: uncolor() { perl -pe 's/\e([^\[\]]|\[.*?[a-zA-Z]|\].*?\a)//g' | col -b; }
# Dependencies: perl, col
#
# Usage: command_with_color_output | uncolor
# Example: ls --color=always | uncolor
#
# Define the function
uncolor() {
    if ! type perl >/dev/null 2>&1; then
        echo "Error: 'perl' command not found. Cannot remove colors." >&2
        cat # Just pass through if perl is missing
        return 1
    fi
     if ! type col >/dev/null 2>&1; then
        echo "Warning: 'col' command not found. Output might contain some lingering control characters." >&2
        perl -pe 's/\e([^\[\]]|\[.*?[a-zA-Z]|\].*?\a)//g' # Run perl only
        return 0 # Not a fatal error
    fi
    perl -pe 's/\e([^\[\]]|\[.*?[a-zA-Z]|\].*?\a)//g' | col -b
}

# Read from stdin and pipe to the function
cat /dev/stdin | uncolor


#!/bin/bash
#
# Script: lsdu
# Description: Lists files and directories using 'ls -l' and sorts the output by size (ascending).
# Based on: lsdu() { ls -l $* | sort --key=5.1 -n; };
# Dependencies: ls, sort
#
# Usage: lsdu [ls options and files/directories...]
# Example: lsdu -h # List current directory, human readable size, sorted by size asc
# Example: lsdu -lh /var # List /var, long format, human readable, sorted by size asc
#
lsdu() {
    # Use ls with provided arguments, then sort by the 5th field (size) numerically
    ls -l "$@" | sort --key=5.1 -n
}

lsdu "$@"

#!/bin/bash
#
# Script: lsduf
# Description: Lists files and directories using 'ls -l', filters by a pattern using grep, and sorts by size (ascending).
# Based on: lsduf() { ls -l | egrep $* | sort --key=5.1 -n; };
# Dependencies: ls, egrep, sort
#
# Usage: lsduf <grep_pattern> [ls options and files/directories...]
# Example: lsduf "\.log" -h # List .log files in current dir, human readable size, sorted by size asc
# Example: lsduf "my_file" /tmp/ # List files containing "my_file" in /tmp, sorted by size asc
#
lsduf() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: $0 <grep_pattern> [ls options and files/directories...]"
        echo "Lists files, filters by pattern, and sorts by size ascending."
        return 1
    fi

    local pattern="$1"
    shift # Remove the pattern from arguments before passing the rest to ls

    # Use ls with remaining arguments, pipe to egrep with the pattern, then sort by size numerically
    ls -l "$@" | egrep "$pattern" | sort --key=5.1 -n
}

lsduf "$@"
