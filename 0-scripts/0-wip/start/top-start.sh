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

# Display top help information
print_header "top - System Monitoring Help"
echo "Key Commands:"
echo "  q        - Quit top"
echo "  Space    - Refresh the display"
echo "  k        - Kill a process (enter PID when prompted)"
echo "  r        - Renice a process (change priority)"
echo "  u        - Show processes for a specific user"
echo "  M        - Sort by memory usage"
echo "  P        - Sort by CPU usage"
echo "  T        - Sort by running time"
echo "  1        - Toggle per-core CPU usage"
echo "  f        - Customize displayed fields (press 'o' to reorder)"
echo "  h        - Show help menu"
echo ""

echo "Press Enter to start top..."
read -r  # Wait for user input before starting

# Run top
run_command "top"

