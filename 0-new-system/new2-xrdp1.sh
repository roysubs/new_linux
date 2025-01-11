#!/bin/bash

# Update the system and install required package
echo "Updating the system..."
sudo apt update && sudo apt upgrade -y
echo "Install XRDP..."
sudo apt install -y xrdp

# Detect the current desktop environment (first try XDG_CURRENT_DESKTOP)
DESKTOP_ENV=$(echo $XDG_CURRENT_DESKTOP)

# If the XDG_CURRENT_DESKTOP variable is empty or not set, check running processes
if [[ -z "$DESKTOP_ENV" ]]; then
    echo "Unable to detect the current desktop environment via XDG_CURRENT_DESKTOP."

    # Check for Cinnamon session process using full command line
    if pgrep -f "cinnamon-session" > /dev/null; then
        DESKTOP_ENV="Cinnamon"
    # Check for MATE session process using full command line
    elif pgrep -f "mate-session" > /dev/null; then
        DESKTOP_ENV="MATE"
    # Check for GNOME session process using full command line
    elif pgrep -f "gnome-session" > /dev/null; then
        DESKTOP_ENV="GNOME"
    # Check for KDE session process using full command line
    elif pgrep -f "startplasma-x11" > /dev/null; then
        DESKTOP_ENV="KDE"
    # Check for XFCE session process using full command line
    elif pgrep -f "xfce4-session" > /dev/null; then
        DESKTOP_ENV="XFCE"
    # Check for LXQt session process using full command line
    elif pgrep -f "lxqt-session" > /dev/null; then
        DESKTOP_ENV="LXQt"
    # Check for Unity session process using full command line
    elif pgrep -f "unity" > /dev/null; then
        DESKTOP_ENV="Unity"
    # Check for Pantheon session process using full command line
    elif pgrep -f "pantheon-session" > /dev/null; then
        DESKTOP_ENV="Pantheon"
    fi
fi

# If still no desktop environment is detected, check installed desktop environments
if [[ -z "$DESKTOP_ENV" ]]; then
    echo "No running desktop environment detected. Checking installed desktop environments..."

    # Check installed Cinnamon package
    if dpkg -l | grep -q "cinnamon"; then
        DESKTOP_ENV="Cinnamon"
    # Check installed MATE package
    elif dpkg -l | grep -q "mate"; then
        DESKTOP_ENV="MATE"
    # Check installed GNOME package
    elif dpkg -l | grep -q "gnome"; then
        DESKTOP_ENV="GNOME"
    # Check installed KDE package
    elif dpkg -l | grep -q "kde"; then
        DESKTOP_ENV="KDE"
    # Check installed XFCE package
    elif dpkg -l | grep -q "xfce"; then
        DESKTOP_ENV="XFCE"
    # Check installed LXQt package
    elif dpkg -l | grep -q "lxqt"; then
        DESKTOP_ENV="LXQt"
    # Check installed Unity package
    elif dpkg -l | grep -q "unity"; then
        DESKTOP_ENV="Unity"
    # Check installed Pantheon package
    elif dpkg -l | grep -q "pantheon"; then
        DESKTOP_ENV="Pantheon"
    fi
fi

# Define a function to display information about the desktop environment
function display_desktop_info() {
    case "$1" in
        "Cinnamon")
            echo "Cinnamon: A modern, sleek desktop environment that aims to provide a user-friendly interface, known for its ease of use and rich customization options."
            ;;
        "MATE")
            echo "MATE: A continuation of GNOME 2, MATE provides a traditional desktop experience with a classic user interface and is lightweight on system resources."
            ;;
        "GNOME")
            echo "GNOME: A popular desktop environment designed to be simple, user-friendly, and modern, often focusing on productivity and minimalism."
            ;;
        "KDE")
            echo "KDE Plasma: A highly customizable desktop environment with a rich set of features, providing a beautiful, polished interface with advanced configuration options."
            ;;
        "XFCE")
            echo "XFCE: A lightweight and fast desktop environment, known for its balance between performance and functionality, ideal for low-resource systems."
            ;;
        "LXQt")
            echo "LXQt: A lightweight, modular, and fast desktop environment aimed at providing a traditional desktop experience with low resource consumption."
            ;;
        "Unity")
            echo "Unity: Formerly the default desktop environment for Ubuntu, Unity provides a unique interface with a left-side launcher and top panel integration."
            ;;
        "Pantheon")
            echo "Pantheon: The desktop environment used by elementary OS, designed to be simple, elegant, and user-friendly, with a macOS-like aesthetic."
            ;;
        *)
            echo "Unknown or unsupported desktop environment: $1."
            ;;
    esac
}

# Configure XRDP to use the appropriate session
if [[ "$DESKTOP_ENV" == "Cinnamon" ]]; then
    display_desktop_info "Cinnamon"
    echo "Configuring XRDP to use the Cinnamon session..."
    echo "cinnamon-session" > ~/.xsession
elif [[ "$DESKTOP_ENV" == "MATE" ]]; then
    display_desktop_info "MATE"
    echo "Configuring XRDP to use the MATE session..."
    echo "mate-session" > ~/.xsession
elif [[ "$DESKTOP_ENV" == "GNOME" ]]; then
    display_desktop_info "GNOME"
    echo "Configuring XRDP to use the GNOME session..."
    echo "gnome-session" > ~/.xsession
elif [[ "$DESKTOP_ENV" == "KDE" ]]; then
    display_desktop_info "KDE"
    echo "Configuring XRDP to use the KDE session..."
    echo "startplasma-x11" > ~/.xsession
elif [[ "$DESKTOP_ENV" == "XFCE" ]]; then
    display_desktop_info "XFCE"
    echo "Configuring XRDP to use the XFCE session..."
    echo "startxfce4" > ~/.xsession
elif [[ "$DESKTOP_ENV" == "LXQt" ]]; then
    display_desktop_info "LXQt"
    echo "Configuring XRDP to use the LXQt session..."
    echo "startlxqt" > ~/.xsession
elif [[ "$DESKTOP_ENV" == "Unity" ]]; then
    display_desktop_info "Unity"
    echo "Configuring XRDP to use the Unity session..."
    echo "unity" > ~/.xsession
elif [[ "$DESKTOP_ENV" == "Pantheon" ]]; then
    display_desktop_info "Pantheon"
    echo "Configuring XRDP to use the Pantheon session..."
    echo "pantheon-session" > ~/.xsession
else
    echo "Unknown or unsupported session: $DESKTOP_ENV. Defaulting to Cinnamon session."
    display_desktop_info "Cinnamon"
    echo "cinnamon-session" > ~/.xsession
fi

# Restart XRDP service
sudo systemctl restart xrdp
sudo systemctl enable xrdp
echo
echo "XRDP is set up on port 5589."
echo "From Windows, connect using 'Remote Desktop Connection' with the IP or hostname of this server."
echo "From Linux, connect using 'Remmina' or other packages that can use XRDP to connect."
echo

