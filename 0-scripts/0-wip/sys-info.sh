#!/bin/bash

# Ensure we are running as root (only if necessary)
if [[ $EUID -ne 0 ]]; then
    echo "Elevation required; rerunning as sudo..."
    exec sudo bash "$0" "$@"
fi

# Capture timestamp
COLLECTED_AT=$(date "+%Y-%m-%d %H:%M:%S")

# Get system information
HOSTNAME=$(hostname)
DOMAIN=$(hostname -d 2>/dev/null)  # May be empty
PRIMARY_OWNER=$(whoami)
MAKE=$(dmidecode -s system-manufacturer)
MODEL=$(dmidecode -s system-product-name | grep -v "To Be Filled By O.E.M")
SERIAL=$(dmidecode -s system-serial-number)
CPU_INFO=$(lscpu | grep "Model name" | sed 's/Model name:\s*//')
BIOS_INFO=$(dmidecode -s bios-version)
CPU_CORES=$(lscpu | awk '/^CPU\(s\):/ {print $2}')
NUMA=$(lscpu | awk -F: '/NUMA node0 CPU\(s\)/ {print $2}' | xargs)
LOGICAL_CORES=$(lscpu | awk -F: '/Thread\(s\) per core/ {print $2}' | xargs)

# Get memory information
TOTAL_MEMORY=$(free -g | awk '/Mem:/ {print $2}')

# Get boot time and uptime
BOOT_UP_TIME=$(uptime -s)
UPTIME=$(uptime -p)

# Get network information
IP_ADDRESSES=$(ip -o -4 addr show | awk '{print $2 ": " $4}' | sed 's/\/[0-9]*//')

# Get disk space
DISK_SPACE=$(df -h | grep -E '^/dev/' | awk '{printf "    %-10s %-5s %-5s %-5s %-5s\n", $1, $2, $3, $4, $5}')

# Get OS info
OS_INFO=$(lsb_release -d | cut -f2-)

# Get display information
DISPLAY_CARD=$(lspci | grep -i vga)
DISPLAY_DRIVER=$(modinfo -F filename $(lspci -k | awk '/VGA compatible controller/{getline; print $NF}') 2>/dev/null)

# Get repositories info (deduplicated)
REPOS=$(apt-cache policy | grep "http" | awk '{print $2}' | sort -u)

# Define a function for aligned output
print_aligned() {
    printf "%-16s %s\n" "$1" "$2"
}

# Capture output in a variable
OUTPUT=$(cat <<EOF
CollectedAt:     $COLLECTED_AT
Last Boot Time:  $BOOT_UP_TIME
Uptime:          $UPTIME

Hostname:        $HOSTNAME
OS:              $OS_INFO
Domain:          ${DOMAIN:-(none)}
Primary Owner:   $PRIMARY_OWNER
Make/Model:      $MAKE $MODEL
Serial Number:   $SERIAL
Total Memory:    $TOTAL_MEMORY GB
CPU:             $CPU_INFO
BIOS:            $BIOS_INFO
CPU Cores:       $CPU_CORES
NUMA node0:      $NUMA
Logical Cores:   $LOGICAL_CORES

IP Addresses:
$(echo "$IP_ADDRESSES" | sed 's/^/    /')

Disk Space:
$DISK_SPACE

Display Card:     $DISPLAY_CARD
Display Driver:   ${DISPLAY_DRIVER:-(not found)}

Repositories (/etc/apt/):
$(echo "$REPOS" | sed 's/^/    /')
EOF
)

# Print to screen
echo "$OUTPUT"

# Save to file
echo "$OUTPUT" > ~/sys-info.txt
echo "System information saved to ~/sys-info.txt"

