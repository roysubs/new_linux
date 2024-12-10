#!/bin/bash

# Jump to defined locations via a menu
# dotsource the jj.sh script to load the function into the current shell
# If it is not dotsourced, the function will only execute in a subshell

jj() {
  # Define your list of directories
  local -a dirs=(
    "$HOME/new_linux"
    "$HOME/192.168.1.29-d"
    "$HOME/Desktop"
    "$HOME/Downloads"
    "/var/log"
    "/etc"
    "/root"
  )

  # Generate menu options
  local menu=""
  for i in "${!dirs[@]}"; do
    menu+="$i ${dirs[i]} "
  done

  # Display the menu and capture the selected index
  local choice
  choice=$(dialog --menu "Select a folder to jump to:" 15 50 8 $menu 2>&1 >/dev/tty)

  # Check if the user canceled
  if [ -z "$choice" ]; then
    echo "Operation canceled."
    return
  fi

  # Navigate to the selected directory
  cd "${dirs[choice]}" || { echo "Failed to change directory"; return 1; }

  # Clear the screen and display the contents of the new directory
  ls
  echo
}

