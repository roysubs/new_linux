#!/bin/bash

# Note that this script must be dot sourced, otherwise it will only update the PATH in a subshell.
# Add this line to exit the script if not sourced:
# (return 0 2>/dev/null) || { echo "This script must be sourced (e.g. prefix with '.' or 'source')"; exit 1; }

# Define the new directory
NEW_DIR="$HOME/new_linux"

# Check if the directory exists
if [ ! -d "$NEW_DIR" ]; then
  echo "Directory $NEW_DIR does not exist, so will not be added to \$PATH"
  exit 1   # mkdir -p "$NEW_DIR"
fi

# Add to PATH for the current session, only run if sourced (i.e. if sourced && ...)
(return 0 2>/dev/null) && {
    if [[ "$PATH" != *"$NEW_DIR"* ]]; then   # was :$NEW_DIR: but that test fails if at start or end of line
      echo "Adding $NEW_DIR to PATH for the current session..."
      export PATH="$NEW_DIR:$PATH"
      echo "Updated PATH for the current session: $PATH"
    else
      echo "$NEW_DIR is already in the PATH for the current session."
    fi
}

# Ensure it's added for every new session
PROFILE_FILE="$HOME/.bashrc"  # Change to ~/.zshrc if using Zsh or add logic to detect the shell
if ! grep -q "export PATH=\"$NEW_DIR:\$PATH\"" "$PROFILE_FILE"; then
  echo "Adding $NEW_DIR to PATH in $PROFILE_FILE..."
  echo "export PATH=\"$NEW_DIR:\$PATH\"" >> "$PROFILE_FILE"
else
  echo "$NEW_DIR is already in the PATH in $PROFILE_FILE."
fi

# Inform the user
echo "PATH updated with '$NEW_DIR'"

