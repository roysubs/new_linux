#!/bin/bash

# Define a dictionary (associative array) of packages and their descriptions
declare -A packages=(
    ["vim"]="Highly configurable text editor"
    ["nano"]="Command-line text editor"
    ["zip"]="Package and compress files"
    ["gzip"]="Compression utility"
    ["7zip"]="High compression ratio file archiver"
    ["unzip"]="Extract compressed files"
    ["tar"]="Archiver tool"
    ["wget"]="Non-interactive network downloader"
    ["curl"]="Command-line data transfer tool"
    ["git"]="Version control system"
    ["htop"]="Interactive process viewer"
    ["btop"]="Resource monitoring tool (CPU, memory, processes)"
    ["atop"]="Advanced system monitor (processes, memory, disk, network)"
    ["nmon"]="System performance monitoring tool"
    ["glances"]="Cross-platform system monitoring tool"
    ["dstat"]="Versatile real-time system performance monitor"
    ["sysstat"]="System monitoring tools (sar, iostat, mpstat)"
    ["vmtouch"]="Memory and file I/O management tool"
    ["watch"]="Execute commands periodically"
    ["nethogs"]="Network traffic monitor by process"
    ["bmon"]="Network bandwidth monitor"
    ["conky"]="Lightweight system monitor"
    ["tmux"]="Terminal multiplexer"
    ["jq"]="Command-line JSON processor"
    ["yq"]="Command-line YAML processor"
    ["build-essential"]="Essential packages for building software"
    ["make"]="Build automation tool"
    ["gcc"]="GNU C Compiler"
    ["g++"]="GNU C++ Compiler"
    ["python3"]="Python programming language"
    ["python3-pip"]="Python 3 package installer"
    ["nodejs"]="JavaScript runtime"
    ["npm"]="JavaScript package manager"
    ["zsh"]="Z shell"
    ["fish"]="Friendly interactive shell"
    ["ssh"]="Secure shell client and server"
    ["openssh-server"]="OpenSSH server for remote login"
    ["openssh-client"]="OpenSSH client for remote login"
    ["rsync"]="Remote file synchronization"
    ["cron"]="Job scheduler"
    ["at"]="Job scheduler for one-time tasks"
    ["nmap"]="Network exploration tool"
    ["net-tools"]="Basic network tools"
    ["iputils-ping"]="Network diagnostics tool"
    ["traceroute"]="Trace route to network host"
    ["iftop"]="Network bandwidth monitor"
    ["tcpdump"]="Network packet analyzer"
    ["strace"]="System call tracer"
    ["lsof"]="List open files"
    ["inxi"]="System information tool"
    ["lsb-release"]="Linux Standard Base version info"
    ["exiftool"]="EXIF metadata tool for images"
    ["xvfb"]="X virtual framebuffer"
    ["hwinfo"]="Hardware information tool"
    ["smartmontools"]="SMART disk health monitoring"
    ["acpi"]="ACPI tools for system power management"
    ["dmidecode"]="Hardware information retrieval tool"
    ["neofetch"]="System info tool for the terminal"
    ["screenfetch"]="System info tool for the terminal"
    ["collectd"]="System statistics collection daemon"
    ["munin"]="Networked resource monitoring tool"
    ["nagios-nrpe-server"]="Nagios NRPE server for monitoring"
    ["arandr"]="Screen resolution and display layout tool"
    ["xsel"]="X selection command-line interface"
    ["imagemagick"]="Image manipulation tool"
    ["vlc"]="Media player"
    ["mpv"]="Media player"
    ["transmission"]="BitTorrent client"
    ["qbittorrent"]="BitTorrent client"
    ["docker"]="Platform for developing and running applications"
    ["docker-compose"]="Define and run multi-container Docker applications"
    ["nginx"]="Web server and reverse proxy"
    ["git-lfs"]="Git Large File Storage"
    ["kdenlive"]="Video editor"
    ["gimp"]="GNU Image Manipulation Program"
    ["inkscape"]="Vector graphics editor"
    ["blender"]="3D modeling and rendering software"
    ["ffmpeg"]="Multimedia framework for video, audio, and streaming"
    ["calibre"]="Ebook management software"
    ["pandoc"]="Document conversion tool"
    ["evince"]="Document viewer"
    ["okular"]="Document viewer"
    ["telegram-desktop"]="Telegram desktop client"
    ["wine"]="Windows compatibility layer"
    ["qemu-kvm"]="KVM-based virtualizer"
    ["vagrant"]="Tool for building virtualized development environments"
    ["cryptsetup"]="Disk encryption tool"
    ["ethtool"]="Network interface configuration tool"
    ["clamav"]="Antivirus software"
    ["spamassassin"]="Spam filtering software"
    ["zabbix-agent"]="Zabbix monitoring agent"
)

# Define a log file for dependency installation output
DEPENDENCY_LOG="$HOME/dependency_install_log.txt"

# Start timer
start_time=$(date +%s)

# Check the installed packages
installed_packages=$(dpkg-query -W -f='${Package}\n')

# Arrays to hold installed and uninstalled packages
installed_list=()
uninstalled_list=()

# Check each package
for pkg in "${!packages[@]}"; do
    if echo "$installed_packages" | grep -q "^$pkg$"; then
        installed_list+=("$pkg (${packages[$pkg]})")
    else
        # Prune the descriptions before adding to uninstalled list
        uninstalled_list+=("$pkg")
    fi
done

# Display installed packages
echo -e "\nThese packages were already installed:" | tee -a "$DEPENDENCY_LOG"
echo -e "--------------------" | tee -a "$DEPENDENCY_LOG"
for pkg in "${installed_list[@]}"; do
    echo "$pkg" | tee -a "$DEPENDENCY_LOG"
done


# Display uninstalled packages
echo ""
echo -e "\nThese packages are not installed:" | tee -a "$DEPENDENCY_LOG"
echo -e "--------------------" | tee -a "$DEPENDENCY_LOG"
for pkg in "${uninstalled_list[@]}"; do
    echo "$pkg" | tee -a "$DEPENDENCY_LOG"
done

# Display the full install command
install_command="sudo apt-get install -y ${uninstalled_list[@]}"
echo -e "\nFull command to install uninstalled packages:" | tee -a "$DEPENDENCY_LOG"
echo -e "--------------------" | tee -a "$DEPENDENCY_LOG"
echo -e "\n$install_command"   | tee -a "$DEPENDENCY_LOG"

pause

# Install the uninstalled packages
if [ ${#uninstalled_list[@]} -gt 0 ]; then
    echo -e "\nInstalling uninstalled packages..." | tee -a "$DEPENDENCY_LOG"
    echo -e "--------------------" | tee -a "$DEPENDENCY_LOG"
    eval $install_command | tee -a "$DEPENDENCY_LOG"
else
    echo -e "\nNo packages to install." | tee -a "$DEPENDENCY_LOG"
fi

# End timer and display runtime
end_time=$(date +%s)
runtime=$((end_time - start_time))
echo -e "\nTotal runtime: $runtime seconds" | tee -a "$DEPENDENCY_LOG"

    # Has installation steps, not automatic
    #    ["postfix"]="Mail Transfer Agent"
    #    ["wireshark"]="Network protocol analyzer"
    
    # ["libreoffice"]="Open-source office suite"
    # ["libreoffice-calc"]="Spreadsheet application"
    # ["libreoffice-writer"]="Word processing application"
    # ["libreoffice-impress"]="Presentation software"
    # ["apache2"]="Apache HTTP Server"
    # ["postgresql"]="PostgreSQL database server"
    # ["mongodb"]="MongoDB NoSQL database"
    # ["redis-server"]="In-memory data structure store"
    # ["php"]="PHP scripting language"
    # ["php-cli"]="PHP command line interface"
    # ["php-mysql"]="PHP MySQL extension"
    # ["php-fpm"]="PHP FastCGI Process Manager"
    # ["postgresql-client"]="PostgreSQL client utilities"
    # ["libapache2-mod-php"]="PHP module for Apache2"
    # ["bind9"]="DNS server"
    # ["snapd"]="Snap package management system"
    # ["flatpak"]="Package management system for desktop applications"
    # ["ntfs-3g"]="NTFS filesystem driver"
    # ["btrfs-progs"]="Btrfs filesystem utilities"
    # ["exfat-fuse"]="ExFAT filesystem support"
    # ["lvm2"]="LVM2 management tools"
    # ["make"]="Build automation tool"
    # ["gcc"]="GNU C Compiler"
    # ["g++"]="GNU C++ Compiler"
    # ["docker"]="Platform for developing, shipping, and running applications"
    # ["docker-compose"]="Define and run multi-container Docker applications"
    # ["nginx"]="Web server and reverse proxy server"
    # ["ufw"]="Uncomplicated Firewall"
    # ["fail2ban"]="Intrusion prevention software"
    # ["firewalld"]="Dynamic firewall manager"
    # ["vim-gtk3"]="Vi IMproved with GTK3 support"
    # ["git-lfs"]="Git Large File Storage"
    # ["kdenlive"]="Video editor"
    # ["gimp"]="GNU Image Manipulation Program"
    # ["inkscape"]="Vector graphics editor"
    # ["blender"]="3D modeling and rendering software"
    # ["ffmpeg"]="Multimedia framework for video, audio, and streaming"
    # ["libreoffice"]="Open-source office suite"
    # ["libreoffice-calc"]="Spreadsheet application"
    # ["libreoffice-writer"]="Word processing application"
    # ["libreoffice-impress"]="Presentation software"
    # ["calibre"]="Ebook management software"
    # ["pandoc"]="Document conversion tool"
    # ["evince"]="Document viewer"
    # ["okular"]="Document viewer"
    # ["spotify-client"]="Spotify client for Linux"
    # ["snapd"]="Snap package management system"
    # ["flatpak"]="Package management system for desktop applications"
    # ["telegram-desktop"]="Telegram desktop client"
    # ["slack-desktop"]="Slack desktop client"
    # ["discord"]="Discord chat client"
    # ["zoom"]="Video conferencing software"
    # ["wine"]="Windows compatibility layer"
    # ["playonlinux"]="Windows software installer for Linux"
    # ["virtualbox"]="Virtualization software"
    # ["libvirt-bin"]="Virtualization management tool"
    # ["qemu-kvm"]="KVM-based virtualizer"
    # ["vagrant"]="Tool for building and maintaining virtualized development environments"
    # ["ntfs-3g"]="NTFS filesystem driver"
    # ["fuse"]="Filesystem in Userspace"
    # ["zfsutils-linux"]="ZFS filesystem utilities"
    # ["btrfs-progs"]="Btrfs filesystem utilities"
    # ["exfat-fuse"]="ExFAT filesystem support"
    # ["cryptsetup"]="Disk encryption tool"
    # ["lvm2"]="LVM2 management tools"
    # ["tftp-hpa"]="Trivial File Transfer Protocol server"
    # ["vsftpd"]="Very Secure FTP Daemon"

# E: has no installation candidate
    # ["xrandr"]="Resize, rotate, and reflect the X display"
    # ["mysql-server"]="MySQL database server"
    # ["vtop"]="Terminal-based visual process monitor (not in apt)"
    # ["mongodb"]="MongoDB NoSQL database"
    # ["playonlinux"]="Windows software installer for Linux"
    # ["sar"]="System Activity Report"
    # ["zfsutils-linux"]="ZFS filesystem utilities"
    # ["lsusb"]="List USB devices"
    # ["lspci"]="List PCI devices"
    # ["discord"]="Discord chat client"
    # ["slack-desktop"]="Slack desktop client"
    # ["zoom"]="Video conferencing software"
    # ["dovecot"]="IMAP and POP3 email server"
    # ["spotify-client"]="Spotify client for Linux"
    # ["openjdk-11-jdk"]="OpenJDK 11 development kit"
    # ["iotop"]="Monitor disk I/O usage by processes"
    # ["iotop-curses"]="Console-based disk I/O monitoring tool"
    # ["ps"]="The ps command with various options is widely used for monitoring processes, although it lacks the real-time updates of htop."
    # ["exim4"]="Mail Transfer Agent"
    # fuse3 breaks: ["fuse"]="Filesystem in Userspace"
