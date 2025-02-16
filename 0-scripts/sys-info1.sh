#!/bin/bash

# Get basic system information
hostname=$(hostname)
os=$(lsb_release -d | awk -F"\t" '{print $2}')
kernel=$(uname -r)
uptime=$(uptime -p)
cpu_info=$(lscpu | grep "Model name" | awk -F: '{print $2}' | xargs)
cpu_cores=$(nproc)
memory=$(free -h | grep Mem | awk '{print $2}')
disk_info=$(df -h --output=source,size,used,avail,pcent | grep -vE '^Filesystem' | column -t)

# Get IP addresses
ip_addresses=$(ip -o -4 addr show | awk '{print $2": "$4}' | tr '\n' ' ')

# Display the information
echo "Hostname:        $hostname"
echo "Operating System: $os"
echo "Kernel Version:  $kernel"
echo "Uptime:          $uptime"
echo "CPU:             $cpu_info"
echo "CPU Cores:       $cpu_cores"
echo "Memory:          $memory"
echo "IP Addresses:    $ip_addresses"
echo "Disk Space:"
echo "$disk_info"

