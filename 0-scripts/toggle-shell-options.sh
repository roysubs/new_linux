#!/usr/bin/env bash

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Helper function to print headers
heading() {
  echo -e "\n${YELLOW}== $1 ==${NC}"
}

# Helper to print current setting of shopt option
show_shopt() {
  local opt=$1
  local desc=$2
  local state
  shopt -q "$opt"
  state=$?
  if [ $state -eq 0 ]; then
    state="${GREEN}on${NC}"
  else
    state="${RED}off${NC}"
  fi
  printf "%-20s : %s\n" "$opt" "$state"
  [ -n "$desc" ] && echo -e "    ${desc}"
}

# Helper to print current setting of set -o option
show_setopt() {
  local opt=$1
  local desc=$2
  local state
  state=$(set -o | grep "^$opt" | awk '{print $2}')
  if [ "$state" == "on" ]; then
    state="${GREEN}on${NC}"
  else
    state="${RED}off${NC}"
  fi
  printf "%-20s : %s\n" "$opt" "$state"
  [ -n "$desc" ] && echo -e "    ${desc}"
}

heading "Bash Shell Options via shopt"

show_shopt extglob      "Enables extended pattern matching operators like +(pattern)"
show_shopt globstar     "Allows ** to match directories recursively"
show_shopt dotglob      "Includes dotfiles (e.g. .bashrc) in pathname expansion"
show_shopt nullglob     "Makes globs that match nothing expand to zero arguments (not literal)"
show_shopt histappend   "Appends to the history file rather than overwriting"
show_shopt cmdhist      "Multi-line commands are saved as one line in history"
show_shopt lithist      "Multi-line commands are saved with actual newlines"
show_shopt nocaseglob   "Globs are case-insensitive"
show_shopt hostcomplete "Enables hostname completion after '@' in bash"

heading "POSIX Shell Options via set -o"

show_setopt errexit     "Exit the script if any command fails (like 'set -e')"
show_setopt nounset     "Treat unset variables as an error (like 'set -u')"
show_setopt pipefail    "Script fails if any part of a pipeline fails"
show_setopt noclobber   "Prevents overwriting files with > redirection"
show_setopt ignoreeof   "Prevents Ctrl-D from exiting shell"
show_setopt xtrace      "Traces commands as they execute (like 'set -x')"
show_setopt verbose     "Prints shell input lines as they are read (like 'set -v')"

heading "Try enabling options temporarily"

echo -e "${GREEN}Try this interactively:${NC}"
echo -e "  ${GREEN}shopt -s extglob${NC}      # Enable extended globs"
echo -e "  ${GREEN}set -o nounset${NC}        # Catch undefined vars"
echo -e "  ${GREEN}shopt -s nullglob${NC}      # Safer for empty globs"
echo -e "  ${GREEN}set -o errexit${NC}         # Exit on failure"

heading "See All Current shopt Options"
echo -e "${GREEN}shopt -p${NC}"
echo
shopt -p

heading "See All Current set -o Options"
echo -e "${GREEN}set -o${NC}"
echo
set -o

