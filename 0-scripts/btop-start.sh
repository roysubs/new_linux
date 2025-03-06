#!/bin/bash

# Function to print headers in yellow
print_header() {
    echo -e "\e[33m$1\e[0m"
}

# Function to print commands in green before executing them
run_command() {
    echo -e "\e[32m$1\e[0m"
    eval "$1"
}

# Display btop help information
print_header "btop - System Monitoring Help"
echo "Key Commands:"
echo "  q        - Quit btop"
echo "  m / Esc  - Show main menu"
echo "  h / ?    - Show help menu"
echo "  p        - Toggle preset views (Shift+p backwards)"
echo "  CursorKeys - Select a process"
echo "  k        - Kill the selected process"
echo "  s        - Send a sig (choose from list) from selected process"
echo "  t        - Change temperature display mode"
echo "  c        - Toggle CPU usage details"
echo "  n        - Toggle network interface display"
echo "  d        - Toggle disk I/O display"
echo "  f        - Toggle process filtering"
echo "  Esc      - Close any open menu/dialog"
echo ""

echo "Press Enter to start btop..."
read -r  # Wait for user input before starting

# Run btop
run_command "btop"
