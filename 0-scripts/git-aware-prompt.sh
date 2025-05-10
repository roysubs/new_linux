#!/bin/bash

# --- Git-aware Bash prompt ---
# Source this file in .bashrc or manually to activate a prompt like:
# user@host:path (branch 2+ 1- 3?) ▲1 ▼2  $ 

Is_Sourced() {
    [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

print_intro() {
    local CYAN=$(tput setaf 6)
    local GREEN=$(tput setaf 2)
    local RED=$(tput setaf 1)
    local YELLOW=$(tput setaf 3)
    local MAGENTA=$(tput setaf 5)
    local RESET=$(tput sgr0)
    local BOLD=$(tput bold)

    echo "${BOLD}${CYAN}Git-aware Bash Prompt${RESET}"
    echo
    echo "${BOLD}Usage:${RESET}"
    echo "──────────────────────────────────────────────────────────────────────────────"
    echo " ${CYAN}source git-aware-prompt.sh${RESET}          # Activates the Git-aware prompt"
    echo " ${CYAN}source git-aware-prompt.sh restore${RESET}  # Restores original PS1 and prompt behavior"
    echo " ${CYAN}source git-aware-prompt.sh --help${RESET}   # Shows this help"
    echo
    echo "${BOLD}Note:${RESET}"
    echo "──────────────────────────────────────────────────────────────────────────────"
    echo " This script must be run with ${BOLD}source${RESET} to take effect (not run directly):"
    echo "     ${CYAN}source git-aware-prompt.sh${RESET}"
    echo
    echo " These prompt changes are only visible inside a Git project folder."
    echo
    echo "${BOLD}How it works:${RESET}"
    echo "──────────────────────────────────────────────────────────────────────────────"
    echo " • Shows the Git branch and working directory status directly in your prompt."
    echo " • Uses Git's own color conventions:"
    echo "     ${GREEN}Green   ( + )${RESET}  Staged files"
    echo "     ${RED}Red     ( - )${RESET}  Unstaged changes"
    echo "     ${YELLOW}Yellow  ( ? )${RESET}  Untracked files"
    echo "     ${CYAN}Cyan     ▲N ${RESET}  Ahead of upstream by N commits"
    echo "     ${MAGENTA}Magenta  ▼M ${RESET}  Behind upstream by M commits"
    echo
    echo "${BOLD}Prompt format:${RESET}"
    echo "──────────────────────────────────────────────────────────────────────────────"
    echo " <Existing prompt, e.g. user@host:path> (${CYAN}branch${RESET} ${GREEN}2+${RESET} ${RED}1-${RESET} ${YELLOW}3?${RESET}) ${CYAN}▲1${RESET} ${MAGENTA}▼2${RESET} \$"
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
    echo -e "\nError: Must be sourced, not executed" >&2
    exit 1
fi

if [ "$1" = "restore" ]; then
    restore_prompt
    return
fi

if [ -z "${__original_ps1+x}" ]; then
    __original_ps1="$PS1"
fi

if [ -z "${__original_prompt_command+x}" ]; then
    __original_prompt_command="$PROMPT_COMMAND"
fi

parse_git_branch() {
    git rev-parse --is-inside-work-tree &>/dev/null || return

    local branch dirty staged unstaged untracked ahead behind
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)

    local status output
    output=$(git status --porcelain 2>/dev/null)

    staged=$(echo "$output" | grep -c '^[AMDRCU]')
    unstaged=$(echo "$output" | grep -c '^.[MD]')
    untracked=$(echo "$output" | grep -c '^\?\?')

    [[ "$staged" -gt 0 ]] && dirty+=" \[\e[32m\]${staged}+\[\e[0m\]"
    [[ "$unstaged" -gt 0 ]] && dirty+=" \[\e[31m\]${unstaged}-\[\e[0m\]"
    [[ "$untracked" -gt 0 ]] && dirty+=" \[\e[33m\]${untracked}?\[\e[0m\]"

    if git rev-parse --abbrev-ref @{u} &>/dev/null; then
        ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null)
        behind=$(git rev-list --count HEAD..@{u} 2>/dev/null)

        [[ "$ahead" -gt 0 ]] && dirty+=" \[\e[36m\]▲$ahead\[\e[0m\]"
        [[ "$behind" -gt 0 ]] && dirty+=" \[\e[35m\]▼$behind\[\e[0m\]"
    fi

    echo "(\[\e[36m\]${branch}\[\e[0m\]${dirty})"
}

update_ps1() {
    local git_info="$(parse_git_branch)"
    local original_ps1="${__original_ps1}"

    if [[ -n "$git_info" ]]; then
        if [[ "$original_ps1" =~ (.*)(\\\$ ?)$ ]]; then
            PS1="${BASH_REMATCH[1]} ${git_info} ${BASH_REMATCH[2]}"
        else
            PS1="${original_ps1} ${git_info}"
        fi
    else
        PS1="$original_ps1"
    fi
}

restore_prompt() {
    if [ -n "${__original_ps1+x}" ]; then
        PS1="$__original_ps1"
        echo "Prompt restored."
    fi
    if [ -n "${__original_prompt_command+x}" ]; then
        PROMPT_COMMAND="$__original_prompt_command"
    else
        unset PROMPT_COMMAND
    fi
    unset __original_ps1 __original_prompt_command
    unset -f parse_git_branch update_ps1 restore_prompt Is_Sourced show_usage print_intro
}

show_usage() {
    echo "Usage: source git-aware-prompt.sh [option]"
    echo "Options:"
    echo "  -h, --help     Show help"
    echo "  restore        Revert prompt"
}

if [ "$#" -gt 0 ]; then
    case "$1" in
        -h|--help) show_usage ;;
        restore) return ;;
        *) echo "Unknown option: $1" >&2; show_usage; return 1 ;;
    esac
else
    PROMPT_COMMAND="update_ps1"
    print_intro
    echo "Git-aware prompt ${BOLD}activated${RESET}."
fi
