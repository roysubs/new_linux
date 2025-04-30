#!/bin/bash

# dk-completion-setup.sh
# Sets up bash completion for the 'dk' script if bash-completion is enabled.

# --- Configuration ---
# The target directory for user-specific bash completion files
COMPLETION_DIR="$HOME/.bash_completion.d"
# The target file for the dk completion script
COMPLETION_FILE="$COMPLETION_DIR/dk"

# --- Bash Completion Script Content ---
# This is the content that will be written to the completion file.
# It defines the completion function and associates it with the 'dk' command.
read -r -d '' DK_COMPLETION_SCRIPT << 'EOF'
# Bash completion for the 'dk' script
_dk_completion() {
    local cur prev commands_needing_container
    # Get the current word being completed
    cur="${COMP_WORDS[COMP_CWORD]}"
    # Get the previous word (the dk subcommand)
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # List of dk subcommands that expect a container name next
    # Added 'run' and 'ex' assuming they might take a container name first
    commands_needing_container="start stop rm logs info it ex run"

    # Check if the previous word is one of the commands needing a container name
    if [[ " ${commands_needing_container} " =~ " ${prev} " ]]; then
        # If yes, generate completions from the list of container names
        # Use compgen -W to generate matches from a wordlist
        # Use -W "$(command)" to use the output of a command as the wordlist
        # Redirect stderr to /dev/null to suppress errors if docker is not running
        COMPREPLY=( $(compgen -W "$(docker ps -aq --format '{{.Names}}' 2>/dev/null)" -- "$cur") )
    fi
}

# Associate the _dk_completion function with the 'dk' command
# -F specifies that a function should be used for completion
complete -F _dk_completion dk
EOF

# --- Setup Logic ---

echo "Checking for bash-completion setup..."

# Check if system-wide bash-completion files exist as referenced in your .bashrc
if [ -f /usr/share/bash-completion/bash_completion ] || [ -f /etc/bash_completion ]; then
    echo "System-wide bash-completion found."

    # Check if the user-specific completion file already exists
    if [ -f "$COMPLETION_FILE" ]; then
        echo "Bash completion file for 'dk' already exists at $COMPLETION_FILE."
        echo "No action needed."
    else
        echo "Bash completion file for 'dk' not found."

        # Create the completion directory if it doesn't exist
        if [ ! -d "$COMPLETION_DIR" ]; then
            echo "Creating directory: $COMPLETION_DIR"
            mkdir -p "$COMPLETION_DIR"
            # Ensure the directory is readable and executable by the user
            chmod u+rwx "$COMPLETION_DIR"
        fi

        # Write the completion script content to the file
        echo "Writing completion script to $COMPLETION_FILE"
        echo "$DK_COMPLETION_SCRIPT" > "$COMPLETION_FILE"

        # Make the completion file readable by the user
        chmod u+r "$COMPLETION_FILE"

        echo ""
        echo "Setup complete!"
        echo "To activate the 'dk' bash completion, please source your .bashrc file:"
        echo "  source ~/.bashrc"
        echo "Or open a new terminal session."
        echo ""
        echo "You should now be able to type 'dk start <Tab>' (or other commands like stop, rm, logs, info, it) and see container names."

    fi

else
    echo "System-wide bash-completion files (/usr/share/bash-completion/bash_completion or /etc/bash_completion) not found."
    echo "Bash completion for 'dk' cannot be set up automatically."
    echo "Please ensure bash-completion is installed and enabled in your .bashrc."
fi

exit 0

