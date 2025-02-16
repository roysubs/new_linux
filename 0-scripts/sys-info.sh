#!/bin/bash

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo "$0" "$@"
fi

# Get system information
HOSTNAME=$(hostname)
DOMAIN=$(hostname -d)  # Assuming the domain is part of the hostname
PRIMARY_OWNER=$(whoami)
MODEL=$(dmidecode -s system-manufacturer)  # Get the manufacturer and model of the system
SERIAL=$(dmidecode -s system-serial-number)
CPU_INFO=$(lscpu | grep "Model name" | sed 's/Model name://')
BIOS_INFO=$(dmidecode -s bios-version)
CPU_CORES=$(lscpu | grep "CPU(s):" | sed 's/CPU(s): //')
NUMA=$(lscpu | grep "NUMA node0" | sed 's/NUMA node0://')
LOGICAL_CORES=$(lscpu | grep "Thread(s) per core" | sed 's/Thread(s) per core://')

# Get memory information
TOTAL_MEMORY=$(free -g | grep Mem | awk '{print $2}')

# Get boot time and uptime
BOOT_UP_TIME=$(uptime -s)
CURRENT_DATE=$(date)
UPTIME=$(uptime -p)

# Get network information
IP_ADDRESSES=$(ip -o -4 addr show | awk '{print $2 ": " $4}' | sed 's/\/[0-9]*//')

# Get disk space
DISK_SPACE=$(df -h | grep -E '^/dev/' | awk '{print $1, $2, $3, $4, $5}')

# Get OS info
OS_INFO=$(lsb_release -d | cut -f2-)

# Get display information
DISPLAY_CARD=$(lspci | grep -i vga)
DISPLAY_DRIVER=$(lshw -C video | grep "configuration" | awk -F: '{print $2}' | awk '{print $1}')

# Get repositories info (e.g., PPAs and other sources)
REPOS=$(apt-cache policy | grep "http" | sed 's/^\s*//')

# Display the information in a structured way
echo "Hostname:        $HOSTNAME"
echo "OS:              $OS_INFO"
echo "Domain:          $DOMAIN"
echo "Primary Owner:   $PRIMARY_OWNER"
echo "Make/Model:      $MODEL"
echo "Serial Number:   $SERIAL"
echo "Total Memory:    $TOTAL_MEMORY GB"
echo "CPU:             $CPU_INFO"
echo "BIOS:            $BIOS_INFO"
echo "CPU Cores:       $CPU_CORES"
echo "NUMA node0:      $NUMA"
echo "Logical Cores:   $LOGICAL_CORES"
echo "Last Boot Time:  $BOOT_UP_TIME"
echo "Uptime:          $UPTIME"
echo "IP Addresses:"
echo "$IP_ADDRESSES" | sed 's/^/    /'
echo "Disk Space:"
echo "$DISK_SPACE" | sed 's/^/    /'
echo "Display Card:    $DISPLAY_CARD"
echo "Display Driver:  $DISPLAY_DRIVER"
echo "Repositories:"
echo "$REPOS" | sed 's/^/    /'

