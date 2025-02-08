#!/bin/bash

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo "$0" "$@"
fi

# Function to display and run a command then check its success
run_command() {
    echo -e "\033[1;33mRunning: $1\033[0m"
    eval "$1"
    if [ $? -ne 0 ]; then
        echo -e "\033[31mError: Command failed - $1\033[0m\n"
        exit 1
    fi
}

# Function to prompt user before running a section
run_section_prompt() {
    local section="$1"
    local function_name="$2"
    echo ""
    echo -e "\033[1;33m=== $section ===\033[0m"

    # Extract and display everything in a function's body including comments, so that user can decide on running or not
    awk "/^${function_name}\(\) *\{/,/^}/ {if (!match(\$0, /^${function_name}\(\) *\{/) && \$0 != \"}\") print}" "$0"

    echo ""  
    read -p "Run this section? (y/N): " choice
    case "$choice" in
        y|Y ) $function_name;;
        * ) echo "Skipping $section.";;
    esac
}

# Read this script to get all functions then prompt if the user wants to run each one by one
run_functions() {
    for func in $(awk '/^[a-zA-Z_][a-zA-Z0-9_]*\(\) *\{/{print substr($1, 1, length($1)-2)}' "$0" | grep -Ev '^(run_command|run_section_prompt|run_functions|run_function_summary)$'); do  
        run_section_prompt "$func" "$func"  
        echo ""  
    done  
    echo "All selected sections completed."
}

# Display a summary of all function names and descriptions
run_function_summary() {
    # Loop through all functions except those starting with 'run_'
    awk '/^[a-zA-Z_][a-zA-Z0-9_]*\(\) *\{/{print substr($1, 1, length($1)-2)}' "$0" | grep -Ev '^run_' | while read -r function_name; do
        # Extract the first comment line in the function body
        comment=$(awk -v func_name="$function_name" '
            BEGIN {in_func = 0}
            /^'"$func_name"' *\(\) *\{/ {in_func = 1}
            in_func && /^#/ {print substr($0, 2); exit}
            in_func && /^\}/ {in_func = 0}
        ' "$0")
        
        # Display function name and comment (if available)
        if [ -n "$comment" ]; then
            echo "$function_name: $comment"
        else
            echo "$function_name"
        fi
    done
}

####################
#
# Each function will be displayed as a section that the user can choose to execute or not
#
####################


update_system() {
# Section: Update and upgrade the system
  run_command "apt-get update -y"
  run_command "apt-get upgrade -y"
  run_command "apt-get dist-upgrade -y"
}

install_vscode() {
# Section: Install and configure Visual Studio Code
  run_command "curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg"
  run_command "echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main' | tee /etc/apt/sources.list.d/vscode.list"
  run_command "apt-get update -y"
  run_command "apt-get install -y code"
}

install_slack() {
# Section: Install and configure Slack
  run_command "wget https://downloads.slack-edge.com/linux_releases/slack-desktop-4.12.2-amd64.deb -O /tmp/slack.deb"
  run_command "dpkg -i /tmp/slack.deb"
  run_command "apt-get install -f -y"
}

install_spotify() {
# Section: Install and configure Spotify
  run_command "curl -sS https://download.spotify.com/debian/pubkey_0D811D58.gpg | apt-key add -"
  run_command "echo 'deb http://repository.spotify.com stable non-free' | tee /etc/apt/sources.list.d/spotify.list"
  run_command "apt-get update -y"
  run_command "apt-get install -y spotify-client"
}

install_discord() {
# Section: Install and configure Discord
  run_command "wget -O /tmp/discord.deb 'https://discord.com/api/download?platform=linux&format=deb'"
  run_command "dpkg -i /tmp/discord.deb"
  run_command "apt-get install -f -y"
}

install_steam() {
# Section: Install and configure Steam
  run_command "dpkg --add-architecture i386"
  run_command "apt-get update -y"
  run_command "apt-get install -y steam"
}

install_wine() {
# Section: Install and configure Wine
  run_command "dpkg --add-architecture i386"
  run_command "wget -O /etc/apt/sources.list.d/winehq.list https://dl.winehq.org/wine-builds/debian/dists/$(lsb_release -cs)/winehq-$(lsb_release -cs).sources"
  run_command "apt-get update -y"
  run_command "apt-get install -y --install-recommends winehq-stable"
}

install_gimp() {
# Section: Install and configure GIMP
  run_command "apt-get install -y gimp"
}

install_inkscape() {
# Section: Install and configure Inkscape
  run_command "apt-get install -y inkscape"
}

install_blender() {
# Section: Install and configure Blender
  run_command "apt-get install -y blender"
}

install_audacity() {
# Section: Install and configure Audacity
  run_command "apt-get install -y audacity"
}

install_handbrake() {
# Section: Install and configure HandBrake
  run_command "apt-get install -y handbrake"
}

install_obs_studio() {
# Section: Install and configure OBS Studio
  run_command "apt-get install -y obs-studio"
}

install_kdenlive() {
# Section: Install and configure Kdenlive
  run_command "apt-get install -y kdenlive"
}

install_libreoffice() {
# Section: Install and configure LibreOffice
  run_command "apt-get install -y libreoffice"
}

install_gparted() {
# Section: Install and configure GParted
  run_command "apt-get install -y gparted"
}

install_synaptic() {
# Section: Install and configure Synaptic Package Manager
  run_command "apt-get install -y synaptic"
}

install_gnome_tweaks() {
# Section: Install and configure Gnome Tweaks
  run_command "apt-get install -y gnome-tweaks"
}

# Section: Install and configure Gnome Tweak Tool
install_gnome_tweak_tool() {
  run_command "apt-get install -y gnome-tweak-tool"
}

install_gnome_extensions() {
# Section: Install and configure Gnome Extensions
  run_command "apt-get install -y gnome-shell-extensions"
}

install_gnome_software() {
# Section: Install and configure Gnome Software
  run_command "apt-get install -y gnome-software"
}

install_gnome_calculator() {
# Section: Install and configure Gnome Calculator
  run_command "apt-get install -y gnome-calculator"
}

install_gnome_screenshot() {
# Section: Install and configure Gnome Screenshot
  run_command "apt-get install -y gnome-screenshot"
}

install_gnome_disk_utility() {
# Section: Install and configure Gnome Disk Utility
  run_command "apt-get install -y gnome-disk-utility"
}

install_gnome_system_monitor() {
# Section: Install and configure Gnome System Monitor
  run_command "apt-get install -y gnome-system-monitor"
}

install_gnome_terminal() {
# Section: Install and configure Gnome Terminal
  run_command "apt-get install -y gnome-terminal"
}

install_gnome_weather() {
# Section: Install and configure Gnome Weather
  run_command "apt-get install -y gnome-weather"
}

install_gnome_maps() {
# Section: Install and configure Gnome Maps
  run_command "apt-get install -y gnome-maps"
}

install_gnome_photos() {
# Section: Install and configure Gnome Photos
  run_command "apt-get install -y gnome-photos"
}

install_gnome_music() {
# Section: Install and configure Gnome Music
  run_command "apt-get install -y gnome-music"
}

install_gnome_contacts() {
# Section: Install and configure Gnome Contacts
  run_command "apt-get install -y gnome-contacts"
}

install_gnome_calendar() {
# Section: Install and configure Gnome Calendar
  run_command "apt-get install -y gnome-calendar"
}

install_gnome_clocks() {
# Section: Install and configure Gnome Clocks
  run_command "apt-get install -y gnome-clocks"
}

install_gnome_todo() {
# Section: Install and configure Gnome Todo
  run_command "apt-get install -y gnome-todo"
}

install_gnome_recipes() {
# Section: Install and configure Gnome Recipes
  run_command "apt-get install -y gnome-recipes"
}

install_gnome_characters() {
# Section: Install and configure Gnome Characters
  run_command "apt-get install -y gnome-characters"
}

install_gnome_logs() {
# Section: Install and configure Gnome Logs
  run_command "apt-get install -y gnome-logs"
}

install_gnome_boxes() {
# Section: Install and configure Gnome Boxes
  run_command "apt-get install -y gnome-boxes"
}

install_gnome_builder() {
# Section: Install and configure Gnome Builder
  run_command "apt-get install -y gnome-builder"
}

install_gnome_documents() {
# Section: Install and configure Gnome Documents
  run_command "apt-get install -y gnome-documents"
}

install_gnome_games() {
# Section: Install and configure Gnome Games
  run_command "apt-get install -y gnome-games"
}

install_gnome_initial_setup() {
# Section: Install and configure Gnome Initial Setup
  run_command "apt-get install -y gnome-initial-setup"
}

install_gnome_packagekit() {
# Section: Install and configure Gnome PackageKit
  run_command "apt-get install -y gnome-packagekit"
}

install_gnome_session() {
# Section: Install and configure Gnome Session
  run_command "apt-get install -y gnome-session"
}

install_gnome_settings_daemon() {
# Section: Install and configure Gnome Settings Daemon
  run_command "apt-get install -y gnome-settings-daemon"
}

install_gnome_shell() {
# Section: Install and configure Gnome Shell
  run_command "apt-get install -y gnome-shell"
}

install_gnome_shell_extensions() {
# Section: Install and configure Gnome Shell Extensions
  run_command "apt-get install -y gnome-shell-extensions"
}

install_gnome_software() {
# Section: Install and configure Gnome Software
  run_command "apt-get install -y gnome-software"
}

install_gnome_user_share() {
# Section: Install and configure Gnome User Share
  run_command "apt-get install -y gnome-user-share"
}

install_gnome_video_effects() {
# Section: Install and configure Gnome Video Effects
  run_command "apt-get install -y gnome-video-effects"
}

install_gnome_web() {
# Section: Install and configure Gnome Web (Epiphany)
  run_command "apt-get install -y epiphany-browser"
}

install_gnome_xorg() {
# Section: Install and configure Gnome XORG
  run_command "apt-get install -y gnome-xorg"
}

install_gnome_xorg_session() {
# Section: Install and configure Gnome XORG Session
  run_command "apt-get install -y gnome-xorg-session"
}

install_gnome_xorg_settings() {
# Section: Install and configure Gnome XORG Settings
  run_command "apt-get install -y gnome-xorg-settings"
}

install_gnome_xorg_tools() {
# Section: Install and configure Gnome XORG Tools
  run_command "apt-get install -y gnome-xorg-tools"
}

install_gnome_xorg_utils() {
# Section: Install and configure Gnome XORG Utils
  run_command "apt-get install -y gnome-xorg-utils"
}

install_gnome_xorg_xserver() {
# Section: Install and configure Gnome XORG Xserver
  run_command "apt-get install -y gnome-xorg-xserver"
}

install_gnome_xorg_xserver_xorg() {
# Section: Install and configure Gnome XORG Xserver Xorg
  run_command "apt-get install -y gnome-xorg-xserver-xorg"
}

install_gnome_xorg_xserver_xorg_input() {
# Section: Install and configure Gnome XORG Xserver Xorg Input
  run_command "apt-get install -y gnome-xorg-xserver-xorg-input"
}

install_gnome_xorg_xserver_xorg_video() {
# Section: Install and configure Gnome XORG Xserver Xorg Video
  run_command "apt-get install -y gnome-xorg-xserver-xorg-video"
}

install_gnome_xorg_xserver_xorg_wacom() {
# Section: Install and configure Gnome XORG Xserver Xorg Wacom
  run_command "apt-get install -y gnome-xorg-xserver-xorg-wacom"
}

install_gnome_xorg_xserver_xorg_xinput() {
# Section: Install and configure Gnome XORG Xserver Xorg Xinput
  run_command "apt-get install -y gnome-xorg-xserver-xorg-xinput"
}

install_gnome_xorg_xserver_xorg_xnest() {
# Section: Install and configure Gnome XORG Xserver Xorg Xnest
  run_command "apt-get install -y gnome-xorg-xserver-xorg-xnest"
}

install_gnome_xorg_xserver_xorg_xvfb() {
# Section: Install and configure Gnome XORG Xserver Xorg Xvfb
  run_command "apt-get install -y gnome-xorg-xserver-xorg-xvfb"
}

install_gnome_xorg_xserver_xorg_xwayland() {
# Section: Install and configure Gnome XORG Xserver Xorg Xwayland
  run_command "apt-get install -y gnome-xorg-xserver-xorg-xwayland"
}

install_gnome_xorg_xserver_xorg_xwin() {
# Section: Install and configure Gnome XORG Xserver Xorg Xwin
  run_command "apt-get install -y gnome-xorg-xserver-xorg-xwin"
}

install_gnome_xorg_xserver_xorg_xwud() {
# Section: Install and configure Gnome XORG Xserver Xorg Xwud
  run_command "apt-get install -y gnome-xorg-xserver-xorg-xwud"
}

install_gnome_xorg_xserver_xorg_xxkb() {
# Section: Install and configure Gnome XORG Xserver Xorg Xxkb
  run_command "apt-get install -y gnome-xorg-xserver-xorg-xxkb"
}

install_gnome_xorg_xserver_xorg_xxkbcomp() {
# Section: Install and configure Gnome XORG Xserver Xorg Xxkbcomp
  run_command "apt-get install -y gnome-xorg-xserver-xorg-xxkbcomp"
}

install_gnome_xorg_xserver_xorg_xxkbprint() {
# Section: Install and configure Gnome XORG Xserver Xorg Xxkbprint
  run_command "apt-get install -y gnome-xorg-xserver-xorg-xxkbprint"
}

install_gnome_xorg_xserver_xorg_xxkbv() {
# Section: Install and configure Gnome XORG Xserver Xorg Xxkbv
  run_command "apt-get install -y gnome-xorg-xserver-xorg-xxkbv"
}

# final_configuration() {
# # Any wrap-up steps, restart services etc
#   run_command "sudo systemctl restart apache2"
# }
run_function_summary
run_functions
