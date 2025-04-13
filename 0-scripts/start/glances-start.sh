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

# Display Glances help information
print_header "Glances - System Monitoring Help"
echo "Key Commands:"
echo "  q        - Quit Glances"
echo "  s        - Sort processes by a column (CPU, MEM, IO)"
echo "  Enter    - Select a process"
echo "  k        - Kill the selected process"
echo "  c        - Toggle CPU usage per core"
echo "  m        - Show/hide mount point and disk I/O info"
echo "  n        - Show/hide network interfaces"
echo "  d        - Show/hide disk I/O stats"
echo "  f        - Show/hide file system info"
echo "  p        - Show/hide process info"
echo "  l        - Show/hide logs"
echo "  b        - View battery status (if applicable)"
echo "  h        - Display help menu"
echo ""

echo "Press Enter to start Glances..."
read -r  # Wait for user input before starting

# Run Glances
run_command "glances"
