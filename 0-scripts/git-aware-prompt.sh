#!/bin/bash

# This script provides a Git-aware Bash prompt.
# Source this script in your terminal or ~/.bashrc to activate the custom prompt.
# Use 'restore_prompt' function to revert to the original prompt.

# --- Function to check if the script is sourced ---
# Returns 0 (true) if sourced, 1 (false) otherwise.
Is_Sourced() {
    # Compare the script's source file path with the name used to invoke it.
    # They will be different if the script is sourced.
    [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

# --- Ensure the script is sourced ---
# If not sourced, print an error and exit the script (do not exit the shell).
if ! Is_Sourced; then
    echo "Error: This script must be run sourced (e.g., '. ./$(basename "$0")' or 'source ./$(basename "$0")') to change the prompt." 1>&2
    exit 1 # Use exit here to stop script execution when not sourced
fi

# --- Variables to store original prompt settings ---
# We store the original PS1 and PROMPT_COMMAND when the script is sourced.
# This allows the 'restore_prompt' function to revert to the previous state.
# We use '__original_ps1' and '__original_prompt_command' as variable names
# to minimize potential conflicts with existing user variables.
# Check if these variables are already set (e.g., if the script is sourced multiple times)
# If not set, store the current values.
if [ -z "${__original_ps1+x}" ]; then
    # Variable is unset or null, store the current PS1
    __original_ps1="$PS1"
fi

if [ -z "${__original_prompt_command+x}" ]; then
    # Variable is unset or null, store the current PROMPT_COMMAND
    __original_prompt_command="$PROMPT_COMMAND"
fi

# --- Git-aware prompt function ---
# Checks if the current directory is a Git repository and retrieves branch/status info.
# Returns a formatted string suitable for inclusion in the PS1 variable.
parse_git_branch() {
    # Check if we are in a Git repository. If not, exit the function.
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return

    # Get the current branch name.
    local branch=$(git rev-parse --abbrev-ref HEAD)

    # Check for uncommitted changes (staged and unstaged).
    # '--porcelain' provides a stable, machine-readable output.
    local status=$(git status --porcelain 2>/dev/null)
    local dirty=""
    # If the status output is not empty, there are changes.
    if [[ -n "$status" ]]; then
        dirty="*" # Indicator for dirty state (you can change this character)
    fi

    # Check for unpulled/unpushed commits (requires configured upstream branch).
    # Uncomment the lines below if you want indicators for commits ahead/behind upstream.
    # Note: These checks can add a slight delay to the prompt depending on your network.
    # if git rev-list @{u}..HEAD --count >/dev/null 2>&1; then
    #     if [[ $(git rev-list @{u}..HEAD --count) -gt 0 ]]; then
    #         dirty="${dirty}▲" # Ahead of upstream
    #     fi
    # fi
    # if git rev-list HEAD..@{u} --count >/dev/null 2>&1; then
    #     if [[ $(git rev-list HEAD..@{u}..HEAD --count) -gt 0 ]]; then
    #         dirty="${dirty}▼" # Behind upstream
    #     fi
    # fi

    # Output the formatted branch name and status.
    if [[ "$branch" == "HEAD" ]]; then
        # Handle detached HEAD state. Get the short commit hash.
        local commit_hash=$(git rev-parse --short HEAD)
        # Format: (HEAD: <commit_hash><dirty_indicator>) in yellow
        echo "(\[\e[33m\]HEAD: ${commit_hash}\[\e[0m\]${dirty})"
    else
        # Format: (<branch_name><dirty_indicator>) in cyan
        echo "(\[\e[36m\]${branch}\[\e[0m\]${dirty})"
    fi
}

# --- Function to update the PS1 variable ---
# This function is called by PROMPT_COMMAND before each prompt is displayed.
# It calls parse_git_branch and attempts to insert its output
# before the last '\$' in the original PS1 string, with corrected spacing.
update_ps1() {
    local git_info=$(parse_git_branch)
    local original_ps1="${__original_ps1}"
    local git_part="" # Variable to hold the formatted git info with trailing space

    # If git_info is not empty, format it with a trailing space
    if [[ -n "$git_info" ]]; then
        git_part="${git_info} " # Add space *after* the git info
    fi

    # Attempt to find the position of the last '\$' in the original PS1.
    # This uses grep to find everything up to the last '$', and wc -c to count characters.
    # This is an approximation and might not work for all complex PS1 strings.
    local before_dollar_part=$(echo "$original_ps1" | grep -oP '.*\$\K')
    local dollar_pos=$(( $(echo -n "$before_dollar_part" | wc -c) + 1 ))

    # If '\$' is found (position > 0), construct the new PS1 by inserting git_part before it
    if [[ "$dollar_pos" -gt 1 ]]; then # Check > 1 because wc -c can return 0 for an empty string
        # Get the part before '\$'
        local before_dollar="${original_ps1:0:$dollar_pos-1}"
        # Get the part from '\$' onwards
        local from_dollar="${original_ps1:$dollar_pos-1}"
        # Construct the new PS1: part_before_$, git_info_with_space, part_from_$.
        PS1="${before_dollar}${git_part}${from_dollar}"
    else
        # If '\$' is not found or is at the very beginning, just append git_part
        PS1="${original_ps1}${git_part}"
    fi
}


# --- Function to restore the original prompt ---
# Reverts PS1 and PROMPT_COMMAND to their values before this script was sourced.
restore_prompt() {
    # Check if the original values were stored.
    if [ -n "${__original_ps1+x}" ]; then
        PS1="$__original_ps1"
        echo "Bash prompt restored to original state."
    else
        echo "Original PS1 not found. Could not restore prompt."
    fi

    # Restore PROMPT_COMMAND. Handle cases where it was empty or unset.
    if [ -n "${__original_prompt_command+x}" ]; then
         # If original PROMPT_COMMAND was not empty/unset, restore it.
         PROMPT_COMMAND="$__original_prompt_command"
    elif [ -z "${__original_prompt_command+x}" ]; then
         # If original PROMPT_COMMAND was empty or unset, unset it.
         unset PROMPT_COMMAND
    fi

    # Unset the variables used to store original settings and the functions.
    unset __original_ps1 __original_prompt_command
    unset -f parse_git_branch update_ps1 restore_prompt Is_Sourced show_usage
}

# --- Usage message function ---
show_usage() {
    echo "Usage: source /path/to/this/script.sh [option]"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message."
    echo "  restore         Restore the original Bash prompt."
    echo ""
    echo "To activate the custom prompt, source this script:"
    echo "  source /path/to/this/script.sh"
    echo ""
    echo "To restore the original prompt:"
    echo "  source /path/to/this/script.sh restore"
}

# --- Script execution logic ---
# Check for arguments.
if [ "$#" -gt 0 ]; then
    case "$1" in
        -h|--help)
            show_usage
            ;;
        restore)
            restore_prompt
            ;;
        *)
            echo "Unknown option: $1" 1>&2
            show_usage
            return 1 # Use return here to stop script execution when sourced with invalid args
            ;;
    esac
else
    # No arguments, activate the custom prompt.
    # Set PROMPT_COMMAND to run our update function before each prompt.
    # This is what makes the prompt dynamic.
    PROMPT_COMMAND="update_ps1"
    echo "Git-aware Bash prompt activated. Use 'source /path/to/this/script.sh restore' to revert."
fi

