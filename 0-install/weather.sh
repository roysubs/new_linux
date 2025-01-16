#!/bin/bash

# Function to display titles
show_title() {
    echo -e "\n\033[1;34m$1\033[0m"
    echo "================================="
}

# Function to display commands in green
show_command() {
    echo -e "\033[0;32m$1\033[0m"
}

# Function to pause for user input
pause() {
    read -n 1 -s -r -p "Press any key to continue..."
    echo
}

# Function to check and install missing packages
install_if_missing() {
    local cmd=$1
    local pkg=$2
    if ! command -v "$cmd" &> /dev/null; then
        echo "Installing $pkg..."
        sudo apt update && sudo apt install -y "$pkg" || {
            echo -e "\033[0;31mFailed to install $pkg. Please check your repository or network.\033[0m"
            return 1
        }
    fi
}

# Introduction
clear
echo -e "\033[1;33mWelcome to the Weather Tools Demonstration Script\033[0m"
echo "This script demonstrates several weather tools for Linux."
echo -e "\nTools included:"
echo "1. wttr.in       - A web-based weather service accessible via curl or wget."
echo "2. WeeWX         - Weather software suite for weather stations (not demonstrated)."
echo "3. Weather CLI   - Python CLI for fetching weather (if available)."
echo "4. ansiweather   - Lightweight terminal weather app with ANSI color."
echo "5. metar         - Displays raw METAR aviation weather reports."
pause

# 1. wttr.in
show_title "1. wttr.in"
echo "Fetching weather for London using wttr.in..."
install_if_missing "curl" "curl"
show_command "curl wttr.in/London"
curl -s wttr.in/London
pause

# 2. WeeWX
show_title "2. WeeWX"
echo "WeeWX is a weather suite for weather stations. It requires setup and is not demonstrated here."
echo "Learn more at:"
show_command "https://weewx.com"
pause

# 3. Weather CLI
show_title "3. Weather CLI"
echo "A Python-based CLI tool for fetching weather using OpenWeatherMap."

# Check for Python and pip
install_if_missing "python3" "python3"
install_if_missing "pip" "python3-pip"

# Setup virtual environment
VENV_DIR="/tmp/weather-cli-venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating a virtual environment for Weather CLI..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

# Attempt to install weather-cli
if ! pip list | grep -q "weather-cli"; then
    echo "Installing Weather CLI..."
    pip install weather-cli || {
        echo -e "\033[0;31mFailed to install weather-cli. It may not be available.\033[0m"
        deactivate
        pause
        return 1
    }
fi

echo "Fetching weather for London..."
show_command "weather London"
weather London || echo -e "\033[0;31mweather-cli failed to execute. Check your setup.\033[0m"
deactivate
pause

# 4. ansiweather
show_title "4. ansiweather"
install_if_missing "ansiweather" "ansiweather"
echo "Fetching weather for London using ansiweather..."
show_command "ansiweather -l 'London,UK'"
ansiweather -l "London,UK"
pause

# 5. metar
show_title "5. metar"
install_if_missing "metar" "metar"
echo "Fetching METAR data for London Heathrow (EGLL)..."
show_command "metar EGLL"
metar EGLL || echo -e "\033[0;31mmetar failed to fetch data. Check your setup.\033[0m"
pause

# Script completed
echo -e "\n\033[1;32mAll available weather tools demonstrated successfully!\033[0m"

