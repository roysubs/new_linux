#!/bin/bash
# Ensure the PowerShell profile folder and file exist, and add custom keybinding

PROFILE_PATH="$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
KEYBINDING="Set-PSReadlineKeyHandler -Key 'Ctrl+Backspace' -Function BackwardKillWord"

# Check if the directory exists, if not create it
if [ ! -d "$HOME/.config/powershell" ]; then
  mkdir -p "$HOME/.config/powershell"
fi

# Check if the profile file exists, if not create it
if [ ! -f "$PROFILE_PATH" ]; then
  touch "$PROFILE_PATH"
fi

# Add the custom keybinding if it doesn't already exist in the profile
if ! grep -q "$KEYBINDING" "$PROFILE_PATH"; then
  echo "$KEYBINDING" >> "$PROFILE_PATH"
  echo "Custom keybinding added to $PROFILE_PATH"
else
  echo "Keybinding already exists in $PROFILE_PATH"
fi

