#!/bin/bash

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo "$0" "$@"
fi

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)."
    exit 1
fi

# Define associative arrays for each group of tools
declare -A system_tools=(
    [htop]="Interactive process viewer."
    [ncdu]="Disk usage analyzer."
    [tmux]="Terminal multiplexer."
    [screen]="Alternative terminal multiplexer."
    [tree]="Display directory structure."
    [iotop]="Monitor disk I/O."
    [sysstat]="Performance monitoring tools."
    [lsblk]="Display block device info. [util-linux]"
    [parted]="Partition management tool."
    [gparted]="GUI partition manager."
    [lsof]="List open files."
    [dstat]="Comprehensive resource stats."
    [inxi]="System information tool."
)

declare -A file_tools=(
    [rsync]="File synchronization and transfer."
    [rclone]="Sync with cloud storage providers."
    [fdupes]="Detect duplicate files."
    [unrar]="Extract RAR files."
    [zip]="ZIP file utility."
    [unzip]="Extract ZIP files."
    [p7zip]="Handle 7z archives. [p7zip-full]"
    [mc]="Midnight Commander. Console-based file manager."
    [cpio]="Archive and copy tool."
)

declare -A network_tools=(
    [curl]="Transfer data from URLs."
    [wget]="Download files from the web."
    [ifconfig]="Interface config. Display IP configuration. [net-tools]"
    [arp]="Address Resolution Protocol tool. [net-tools]"
    [nmap]="Network mapper."
    [traceroute]="Trace packet routes."
    [mtr]="Ping and traceroute combined."
    [tcpdump]="Network packet analyzer."
    [iftop]="Network bandwidth monitor."
    [whois]="Domain/IP lookup."
)

declare -A dev_tools=(
    [build-essential]="Development tools meta-package."
    [git]="Version control system."
    [cmake]="Build system generator."
    [pip]="Python package installer. [python3-pip]"
    [java]="Java Development Kit. [default-jdk]"
    [gcc]="GNU C Compiler."
    [gdb]="GNU Debugger."
    [valgrind]="Memory debugging tool."
    [clang]="Alternative C/C++ compiler."
    [vim]="Configurable text editor."
    [nano]="Simple text editor."
    [emacs]="Powerful text editor."
)

declare -A security_tools=(
    [fail2ban]="Prevent brute-force attacks."
    [ufw]="Simple firewall interface."
    [clamav]="Open-source antivirus."
    [chkrootkit]="Rootkit detection."
    [john]="Password cracking tool."
    [lynis]="System security auditing."
)

# Function to process and install a group
install_group() {
    local -n group=$1
    local group_name=$2

    echo -e "\nProcessing $group_name...\n"

    local to_install=()
    local already_installed=()

    for tool in "${!group[@]}"; do
        local description="${group[$tool]}"
        local pkg="${description##*. [}" # Extract package name if present
        pkg="${pkg%]}"                   # Remove trailing bracket, if any

        # If no package is specified, assume tool name is the package
        [[ $description != *"["* ]] && pkg="$tool"

        if dpkg -l | grep -q "^ii.*$pkg "; then
            already_installed+=("$tool - ${description} [already installed]")
        else
            to_install+=("$pkg")
            echo "$tool - ${description} [not installed]"
        fi
    done

    echo -e "\nAlready installed tools:"
    printf "%s\n" "${already_installed[@]:-None}"

    if [[ ${#to_install[@]} -gt 0 ]]; then
        local unique_packages=($(printf "%s\n" "${to_install[@]}" | sort -u))
        echo -e "\nThe following packages will be installed:"
        printf "%s " "${unique_packages[@]}"
        echo -e "\n"

        read -p "Do you want to install these packages? (y/n) " choice
        if [[ $choice == "y" || $choice == "Y" ]]; then
            apt update && apt install -y "${unique_packages[@]}"
        else
            echo "Skipped installing $group_name."
        fi
    else
        echo "All packages in $group_name are already installed."
    fi
}

# Main script execution
install_group system_tools "System Tools"
install_group file_tools "File Management Tools"
install_group network_tools "Networking Tools"
install_group dev_tools "Development Tools"
install_group security_tools "Security Tools"

echo -e "\nAll groups processed. Script completed."

