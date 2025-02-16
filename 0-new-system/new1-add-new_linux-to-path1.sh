#!/bin/bash

# Function to clean duplicate entries from PATH
clean_path() {
  PATH=$(echo "$PATH" | tr ':' '\n' | awk '!seen[$0]++' | tr '\n' ':' | sed 's/:$//')
}

# Function to add a directory to PATH
add_to_path() {
  local DIR="$1"

  # Resolve absolute path (handles ~/ correctly)
  DIR=$(realpath -e "$HOME/${DIR/#\~\//}") || { echo "Directory $DIR does not exist, skipping."; return 1; }

  # Add to current session if sourced
  if (return 0 2>/dev/null); then
    if [[ ":$PATH:" != *":$DIR:"* ]]; then
      echo "Adding $DIR to PATH for the current session..."
      export PATH="$DIR:$PATH"
    else
      echo "$DIR is already in the PATH for the current session."
    fi
  fi

  # Ensure it's added to .bashrc
  local PROFILE_FILE="$HOME/.bashrc"
  if ! grep -qxF "export PATH=\"$DIR:\$PATH\"" "$PROFILE_FILE"; then
    echo "Adding $DIR to PATH in $PROFILE_FILE..."
    echo "export PATH=\"$DIR:\$PATH\"" >> "$PROFILE_FILE"
  else
    echo "$DIR is already in $PROFILE_FILE."
  fi
}

# Clean PATH before adding new directories
clean_path

# Apply function to both directories
add_to_path "new_linux"
add_to_path "new_linux/0-scripts"

# Check if script was sourced
if ! (return 0 2>/dev/null); then
  echo -e "\n\033[1;31mWARNING:\033[0m This script was not sourced!"
  echo -e "  - The directories have been added to \033[1m.bashrc\033[0m and will apply next time you start a new shell."
  echo -e "  - However, \033[1mthis current session is NOT updated!\033[0m"
  echo -e "To apply changes now, run:"
  echo -e "  \033[1;32msource ~/.bashrc\033[0m"
else
  echo -e "\n\033[1;32mSuccess!\033[0m PATH updated for the current session and future shells."
fi

# Display updated PATH
echo -e "\nCurrent PATH:\n$PATH"

