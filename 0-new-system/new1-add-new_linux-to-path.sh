#!/bin/bash

# Add ~/new_linux to PATH in both current session (if sourced) and in .bashrc

# Check if the script is sourced (can enable this line to prevent running if not sourced)
# (return 0 2>/dev/null) || { echo "This script must be sourced (e.g. prefix with '.' or 'source')"; exit 1; }

#!/bin/bash

# Function to remove duplicate entries from PATH
clean_path() {
  # Split PATH into unique entries, then recombine
  PATH=$(echo "$PATH" | tr ':' '\n' | awk '!seen[$0]++' | tr '\n' ':' | sed 's/:$//')
}

# Clean PATH before adding new directories
clean_path

# Function to add a directory to PATH
add_to_path() {
  local DIR="$1"
  
  # Resolve ~ to absolute path if required
  DIR=$(eval realpath -e "$DIR")   # Use eval to expand ~

  # Check if the directory exists
  if [ ! -d "$DIR" ]; then
    echo "Directory $DIR does not exist, so it will not be added to \$PATH"
    return 1
  fi

  # Add to PATH for the current session if sourced
  (return 0 2>/dev/null) && {
    if [[ ":$PATH:" != *":$DIR:"* ]]; then
      echo "Adding $DIR to PATH for the current session..."
      export PATH="$DIR:$PATH"
      echo "PATH updated with '$DIR' for the current session."
    else
      echo "$DIR is already in the PATH for the current session."
    fi
  }

  # Ensure the directory is added to PATH in the user's profile file
  local PROFILE_FILE="$HOME/.bashrc"  # Adjust this if using a different shell
  if ! grep -q "export PATH=.*$DIR*" "$PROFILE_FILE"; then
    echo "Adding $DIR to PATH in $PROFILE_FILE..."
    echo "export PATH=\"$DIR:\$PATH\"" >> "$PROFILE_FILE"
  else
    echo "$DIR is already in the PATH in $PROFILE_FILE."
  fi

  echo
  echo "PATH updated with '$DIR'."
  echo
  echo "Current PATH:"
  echo $PATH
  echo
  echo "export PATH line in $PROFILE_FILE:"
  grep "export PATH=" "$PROFILE_FILE"
}

# Apply the function to multiple directories
add_to_path "~/new_linux"
add_to_path "~/new_linux/0-scripts"

echo "
Console Login (TTY Login) order of Profile files:
/etc/profile     # System-wide initialization script for login shells (all shells, not just Bash)
~/.bash_profile  # if present, user-specific, if exists, Bash does not read ~/.bash_login or ~/.profile.
~/.bash_login    # Only if ~/.bash_profile is missing.
~/.profile       # Only if both ~/.bash_profile and ~/.bash_login are missing. Default in Debian (all shells, not just Bash)
~/.bashrc        # This or user shell-specific profiles are not default but commonly called from ~/.profile

GUI Login (via Display Manager, e.g., GDM, LightDM):
GUI login sessions generally load non-login shell configurations.
However, the initialization scripts depend on the Desktop Environment (DE).
Order of Profile Files (Common DEs like GNOME, KDE, XFCE):
/etc/profile     # Loaded by the display manager. Often responsible for system-wide environment variables.
~/.profile       # This file is executed unless overridden by ~/.bash_profile or similar.
Desktop Environment-Specific: ~/.gnomerc (GNOME), ~/.xprofile (KDE and XFCE), etc
Additionally:
System-wide files specific to the DE might also run, such as /etc/X11/Xsession or scripts in /etc/X11/Xsession.d/.

XTerm Session in GUI:
By default, an xterm starts a non-login shell.
However, you can force it to start a login shell (e.g., xterm -ls).

Non-Login Shell:
Bash reads only ~/.bashrc.

Login Shell (if started with xterm -ls):
The order of files is the same as for Console Login:
/etc/profile
~/.bash_profile
~/.bash_login
~/.profile
Summary of Key Files
/etc/profile – System-wide initialization for login shells.
~/.bash_profile, ~/.bash_login, ~/.profile – User-specific login scripts.
~/.bashrc – Always read for non-login interactive shells.

Debugging Tip:
To trace exactly what is loaded in your environment:
echo \$0          # Check the current shell
bash -x --login  # Debug login shell startup scripts
bash -x          # Debug non-login shell startup scripts
"

