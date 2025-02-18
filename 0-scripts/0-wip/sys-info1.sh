#!/bin/bash

output_file=~/sys-info.txt

# Ensure output file is written
exec > >(tee "$output_file") 2>&1

# Check for sudo
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31mElevation required; rerunning as sudo...\e[0m" >&2
    exec sudo "$0" "$@"
fi

if [[ $EUID -eq 0 && -n $SUDO_USER ]]; then
    CURRENT_USER=$SUDO_USER
else
    CURRENT_USER=$(whoami)
fi

echo "Collected At:    $(date '+%Y-%m-%d %H:%M:%S')"
echo "Last Boot Time:  $(who -b | awk '{print $3, $4}')"
echo "Uptime:          $(uptime -p)"
echo ""
echo "Hostname:        $(hostname)"
echo "OS:              $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')"
echo "Domain:          $(hostname -d 2>/dev/null || echo '(none)')"
echo "Current User:    $CURRENT_USER"
echo "Make/Model:      $(sudo dmidecode -s system-manufacturer) $(sudo dmidecode -s system-product-name)"
echo "Serial Number:   $(sudo dmidecode -s system-serial-number)"
echo "Total Memory:    $(free -h | awk '/^Mem:/{print $2}')"
echo "CPU:             $(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ *//')"
echo "BIOS:            $(sudo dmidecode -s bios-version)"
echo "CPU Cores:       $(nproc)"
echo "NUMA node0:      $(lscpu | grep 'NUMA node0 CPU(s):' | awk '{print $NF}')"
echo "Logical Cores:   $(lscpu | grep '^CPU(s):' | awk '{print $2}')"
echo "Display Card:    $(lspci | grep VGA | cut -d' ' -f1-3 --complement)"
echo "Display Driver:  $(glxinfo | grep 'OpenGL renderer string' | cut -d':' -f2 | sed 's/^ *//')"
echo ""
echo "IP Addresses:"
ip -4 -o addr show | awk '{print "    "$2": "$4}' | cut -d/ -f1
echo ""
echo "Disk Space:"
df -h | awk 'NR==1 || /^\/dev\// {printf "    %s %s %s %s %s\n", $1, $2, $3, $4, $5}'
echo ""
echo "Repositories:"
grep -hE '^deb ' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null | awk '{print "    "$2}' | sort -u
echo "System information saved to $output_file"

