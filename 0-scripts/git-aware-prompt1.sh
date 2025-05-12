#!/bin/bash

# --- Git-aware Bash prompt ---
# Source this file in .bashrc or manually to activate a prompt like:
# user@host:path (branch 2+ 1- 3?) ▲1 ▼2  $

Is_Sourced() {
    [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

print_intro() {
    local bold="$(tput bold)"
    local normal="$(tput sgr0)"
    local green="$(tput setaf 2)"
    local red="$(tput setaf 1)"
    local yellow="$(tput setaf 3)"
    local cyan="$(tput setaf 6)"
    local magenta="$(tput setaf 5)"

    cat <<EOF
${bold}${cyan}Git-aware Bash Prompt${normal}
${bold}──────────────────────────────────────────────────────────────────────────────${normal}

${bold}How it works:${normal}
 • Shows Git branch and working directory status directly in your prompt.
 • Uses Git's own color conventions:
     ${green}Green${normal}   ( + )  Staged files
     ${red}Red${normal}     ( - )  Unstaged changes
     ${yellow}Yellow${normal}  ( ? )  Untracked files
     ${cyan}Cyan${normal}    (▲N)   Ahead of upstream by N commits
     ${magenta}Magenta${normal} (▼M)   Behind upstream by M commits

${bold}Prompt format:${normal}
 user@host:path (${cyan}branch${normal} ${green}2+${normal} ${red}1-${normal} ${yellow}3?${normal}) ${cyan}▲1${normal} ${magenta}▼2${normal}  \$

${bold}Legend:${normal}
 • '${green}2+${normal}'   = 2 staged files
 • '${red}1-${normal}'   = 1 unstaged file
 • '${yellow}3?${normal}'   = 3 untracked files
 • '${cyan}▲1${normal}'   = 1 commit ahead of origin
 • '${magenta}▼2${normal}'   = 2 commits behind origin

${bold}Usage:${normal}
 source git-aware-prompt.sh         # Activates the Git-aware prompt
 source git-aware-prompt.sh restore  # Restores original PS1 and prompt behavior
 source git-aware-prompt.sh --help   # Shows this help

${bold}Note:${normal}
 This script must be sourced to take effect:
     source git-aware-prompt.sh
EOF
}

if ! Is_Sourced; then
    print_intro
    echo -e "\nError: Must be sourced, not executed" >&2
    exit 1
fi

if [ -z "${__original_ps1+x}" ]; then
    __original_ps1="$PS1"
fi

if [ -z "${__original_prompt_command+x}" ]; then
    __original_prompt_command="$PROMPT_COMMAND"
fi

declare -a __GIT_VERBOSE_LINES=()

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

    __GIT_VERBOSE_LINES=()

    if [[ "$GIT_PROMPT_VERBOSE" == "1" ]]; then
        echo -e "\e[2m[git status --porcelain]\e[0m"
        echo "$output" | sed 's/^/    /'

        local reset="\e[0m"
        local green="\e[32m"
        local red="\e[31m"
        local yellow="\e[33m"

        if [[ "$staged" -gt 0 ]]; then
            while IFS= read -r file; do
                __GIT_VERBOSE_LINES+=("  ${green}Staged:${reset}    $file")
            done < <(echo "$output" | grep '^[AMDRCU]' | cut -c4-)
        fi
        if [[ "$unstaged" -gt 0 ]]; then
            while IFS= read -r file; do
                __GIT_VERBOSE_LINES+=("  ${red}Unstaged:${reset}  $file")
            done < <(echo "$output" | grep '^.[MD]' | cut -c4-)
        fi
        if [[ "$untracked" -gt 0 ]]; then
            while IFS= read -r file; do
                __GIT_VERBOSE_LINES+=("  ${yellow}Untracked:${reset} $file")
            done < <(echo "$output" | grep '^\?\?' | cut -c4-)
        fi
    fi

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
        if [[ "$original_ps1" =~ (.*)(\\\\\$ ?)$ ]]; then
            PS1="${BASH_REMATCH[1]} ${git_info} ${BASH_REMATCH[2]}"
        else
            PS1="${original_ps1} ${git_info}"
        fi

        if [[ "$GIT_PROMPT_VERBOSE" == "1" && ${#__GIT_VERBOSE_LINES[@]} -gt 0 ]]; then
            for line in "${__GIT_VERBOSE_LINES[@]}"; do
                echo -e "$line"
            done
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
    unset __original_ps1 __original_prompt_command __GIT_VERBOSE_LINES
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
        restore) restore_prompt ;;
        *) echo "Unknown option: $1" >&2; show_usage; return 1 ;;
    esac
else
    PROMPT_COMMAND="update_ps1"
    print_intro
fi

