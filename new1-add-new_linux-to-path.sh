#!/bin/bash

# Check if the script is sourced (can enable this line to prevent running if not sourced)
# (return 0 2>/dev/null) || { echo "This script must be sourced (e.g. prefix with '.' or 'source')"; exit 1; }

# Define the new directory to be added to PATH
NEW_DIR="$HOME/new_linux"

# Check if the directory exists
if [ ! -d "$NEW_DIR" ]; then
  echo "Directory $NEW_DIR does not exist, so will not be added to \$PATH"
  exit 1   # Optionally, create the directory: mkdir -p "$NEW_DIR"
fi

# This only runs if the script is sourced; no point otherwise as it will run in subshell
(return 0 2>/dev/null) && {
  if [[ ":$PATH:" != *":$NEW_DIR:"* ]]; then
    echo "Adding $NEW_DIR to PATH for the current session..."
    export PATH="$NEW_DIR:$PATH"
    echo "PATH updated with '$NEW_DIR' for the current session."
  else
    echo "$NEW_DIR is already in the PATH for the current session."
  fi
}

# Ensure the new directory is added to PATH for all new sessions
PROFILE_FILE="$HOME/.bashrc"  # Change to ~/.zshrc if using Zsh or adjust to detect the shell
if ! grep -q "export PATH=.*$NEW_DIR*" "$PROFILE_FILE"; then
  echo "Adding $NEW_DIR to PATH in $PROFILE_FILE..."
  echo "export PATH=\"$NEW_DIR:\$PATH\"" >> "$PROFILE_FILE"
else
  echo "$NEW_DIR is already in the PATH in $PROFILE_FILE."
fi

# Inform the user that the PATH has been updated
echo
echo "PATH updated with '$NEW_DIR'."
echo
echo "Current PATH:"
echo $PATH
echo
echo "export PATH line in $PROFILE_FILE:"
grep "export PATH=" "$PROFILE_FILE"
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
echo $0          # Check the current shell
bash -x --login  # Debug login shell startup scripts
bash -x          # Debug non-login shell startup scripts
"

