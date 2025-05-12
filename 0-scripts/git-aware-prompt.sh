#!/bin/bash

# --- Git-aware Bash prompt ---
# Source this file in .bashrc or manually to activate a prompt like:
# user@host:path (branch 2+ 1- 3?) ▲1 ▼2  $
CYAN=$(tput setaf 6)
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
RESET=$(tput sgr0)
BOLD=$(tput bold)
# NC is used in an error message, but not defined. Alias to RESET or define as needed.
# Using RESET for NC as it's commonly used for "No Color"
NC=$RESET

Is_Sourced() {
    [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

print_intro() {
    echo "${BOLD}${CYAN}Git-aware Bash Prompt${RESET}"
    echo
    echo "${BOLD}Usage:${RESET}"
    echo "──────────────────────────────────────────────────────────────────────────────"
    echo " ${CYAN}source git-aware-prompt.sh${RESET}         # Activates the Git-aware prompt"
    echo " ${CYAN}source git-aware-prompt.sh restore${RESET}  # Restores original PS1 and prompt behavior"
    echo " ${CYAN}source git-aware-prompt.sh --help${RESET}   # Shows this help"
    echo
    echo "${BOLD}Note: This script must be run with ${CYAN}source${RESET} to take effect (not run directly),"
    echo "and these prompt changes are only visible inside a Git project folder."
    echo
    echo "${BOLD}How it works:${RESET}"
    echo "──────────────────────────────────────────────────────────────────────────────"
    echo " • Shows Git branch and working directory status directly in your prompt."
    echo " • Uses Git's own color conventions:"
    echo "   ${GREEN}( N+ )${RESET}  Staged files in green"
    echo "   ${RED}( N- )${RESET}  Unstaged changes in red"
    echo "   ${YELLOW}( N? )${RESET}  Untracked files in yellow"
    echo "   ${CYAN} ▲N${RESET}     Ahead of upstream by N commits in cyan"
    echo "   ${MAGENTA} ▼M${RESET}     Behind upstream by M commits in magenta"
    echo
    echo "${BOLD}Prompt format:${RESET}"
    echo "──────────────────────────────────────────────────────────────────────────────"
    echo " user@host:path (${CYAN}branch${RESET} ${GREEN}2+${RESET} ${RED}1-${RESET} ${YELLOW}3?${RESET}) ${CYAN}▲1${RESET} ${MAGENTA}▼2${RESET}  \$"
    echo
    echo "${BOLD}Legend:${RESET}"
    echo "──────────────────────────────────────────────────────────────────────────────"
    echo " • '${GREEN}2+${RESET}'   = 2 staged files"
    echo " • '${RED}1-${RESET}'   = 1 unstaged file"
    echo " • '${YELLOW}3?${RESET}'   = 3 untracked files"
    echo " • '${CYAN}▲1${RESET}'   = 1 commit ahead of origin"
    echo " • '${MAGENTA}▼2${RESET}'   = 2 commits behind origin"
}

if ! Is_Sourced; then
    print_intro
    echo
    echo "${RED}Error: Must be sourced, not executed${NC}"
    echo
    exit 1
fi

# Store original PS1 and PROMPT_COMMAND only once
if [ -z "${__git_aware_prompt_original_ps1+x}" ]; then
    __git_aware_prompt_original_ps1="$PS1"
fi

if [ -z "${__git_aware_prompt_original_prompt_command+x}" ]; then
    __git_aware_prompt_original_prompt_command="$PROMPT_COMMAND"
fi

restore_prompt() {
    if [ -n "${__git_aware_prompt_original_ps1+x}" ]; then
        PS1="$__git_aware_prompt_original_ps1"
        echo "Prompt restored."
        echo
    fi
    if [ -n "${__git_aware_prompt_original_prompt_command+x}" ]; then
        if [ -z "$__git_aware_prompt_original_prompt_command" ]; then
            unset PROMPT_COMMAND # Truly unset if it was originally empty/unset
        else
            PROMPT_COMMAND="$__git_aware_prompt_original_prompt_command"
        fi
    else
        unset PROMPT_COMMAND # Fallback, if it was somehow not set
    fi
    unset __git_aware_prompt_original_ps1 __git_aware_prompt_original_prompt_command
    unset -f parse_git_branch update_ps1 restore_prompt Is_Sourced show_usage print_intro
}


if [ "$1" = "restore" ]; then
    restore_prompt
    return
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    print_intro
    return
fi


parse_git_branch() {
    git rev-parse --is-inside-work-tree &>/dev/null || return

    local branch dirty="" staged unstaged untracked ahead behind output

    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)
    output=$(git status --porcelain --untracked-files=normal 2>/dev/null)

    if [ -z "${output}" ] && git rev-parse --is-inside-work-tree &>/dev/null ; then
        staged="0"
        unstaged="0"
        untracked="0"
    elif [ -n "${output}" ]; then
        staged=$(echo "${output}" | command grep -c '^[AMDRCU]')
        unstaged=$(echo "${output}" | command grep -c '^.[MD]')
        # Using awk for untracked files due to issues with grep '^\?\?' in some environments
        untracked=$(echo "${output}" | command awk '/^\?\?/{c++} END{print c+0}')
    else
        staged="0"
        unstaged="0"
        untracked="0"
    fi

    # Ensure counts are numbers for arithmetic tests, default to 0 if empty or not a number
    staged=${staged:-0}
    unstaged=${unstaged:-0}
    untracked=${untracked:-0}

    [[ "${staged}" -gt 0 ]] && dirty+=" \[\e[32m\]${staged}+\[\e[0m\]"
    [[ "${unstaged}" -gt 0 ]] && dirty+=" \[\e[31m\]${unstaged}-\[\e[0m\]"
    [[ "${untracked}" -gt 0 ]] && dirty+=" \[\e[33m\]${untracked}?\[\e[0m\]"

    if git rev-parse --abbrev-ref @{u} &>/dev/null; then
        ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null)
        behind=$(git rev-list --count HEAD..@{u} 2>/dev/null)

        [[ "$ahead" -gt 0 ]] && dirty+=" \[\e[36m\]▲$ahead\[\e[0m\]"
        [[ "$behind" -gt 0 ]] && dirty+=" \[\e[35m\]▼$behind\[\e[0m\]"
    fi

    echo "(\[\e[36m\]${branch}\[\e[0m\]${dirty})"
}

update_ps1() {
    local git_info
    git_info="$(parse_git_branch)"

    if [[ -n "$git_info" ]]; then
        # The regex (.*) (capture everything before) then ([\$#]\s*) (capture $ or #, then optional spaces) $ (at the end of the string)
        local regex='(.*)([\$#]\s*)$'
        if [[ "$__git_aware_prompt_original_ps1" =~ $regex ]]; then
            PS1="${BASH_REMATCH[1]} ${git_info} ${BASH_REMATCH[2]}"
        else
            echo "DEBUG: Regex DID NOT MATCH. Prefixing git_info." >&2
            PS1="${git_info} ${__git_aware_prompt_original_ps1} "
        fi
    else
        PS1="$__git_aware_prompt_original_ps1"
    fi
}


show_usage() { 
    echo "Usage: source git-aware-prompt.sh [option]"
    echo "Options:"
    echo "  -h, --help     Show help"
    echo "  restore        Revert prompt to original state"
}


if [ "$#" -gt 0 ]; then
    case "$1" in
        *)
            echo "Unknown option: $1" >&2
            show_usage 
            return 1
            ;;
    esac
else
    PROMPT_COMMAND="update_ps1${__git_aware_prompt_original_prompt_command:+;}${__git_aware_prompt_original_prompt_command}"
    print_intro 
    echo -e "Git-aware prompt ${BOLD}activated${RESET}."
    echo
fi
