#!/bin/bash

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RESET='\033[0m'

# Ping Troubleshooting Guide

echo -e "${YELLOW}Ping Troubleshooting Guide${RESET}"
echo -e "${GREEN}Check if the network interface has an IP address:${RESET}"
echo -e "${GREEN}ip addr${RESET}"
read -n1 -s -r -p "Press any key to continue..."
echo;echo
echo -e "${YELLOW}Check Network Configuration (Alternative Command)${RESET}"
echo -e "${GREEN}ifconfig${RESET}"
echo -e "(May require installation)\n"
read -n1 -s -r -p "Press any key to continue..."
echo;echo
echo -e "${YELLOW}Bring the Network Interface Up${RESET}"
echo -e "${GREEN}sudo ip link set <interface> up${RESET}"
echo "Replace <interface> with eth0, wlan0, etc."
read -n1 -s -r -p "Press any key to continue..."
echo;echo
echo -e "${YELLOW}Use nmcli for Network Management${RESET}"
echo -e "${GREEN}nmcli dev status${RESET}"
echo "Example output shows device status and connections.
DEVICE          TYPE      STATE                   CONNECTION 
wlp2s0          wifi      connected               VM9469879  
lo              loopback  connected (externally)  lo         
p2p-dev-wlp2s0  wifi-p2p  disconnected            --         
eno1            ethernet  unavailable             --     "
read -n1 -s -r -p "Press any key to continue..."
# Allowing ICMP Traffic (Ping)
echo;echo
echo -e "${YELLOW}Allow ICMP Traffic${RESET}"
echo -e "${GREEN}To allow incoming ICMP (ping):${RESET}"
echo -e "${GREEN}sudo ufw allow in to any port 0:65535 proto icmp${RESET}"
echo -e "${GREEN}To allow outgoing ICMP (ping):${RESET}"
echo -e "${GREEN}sudo ufw allow out to any port 0:65535 proto icmp${RESET}"
echo "This ensures ICMP traffic is permitted while maintaining firewall security."
read -n1 -s -r -p "Press any key to continue..."
echo;echo
# Connectivity Tests
echo;echo
echo -e "${YELLOW}Test Connectivity${RESET}"
echo -e "${GREEN}ping -c 4 <gateway-ip>${RESET}"
echo "Test connectivity to the network gateway."
echo -e "${GREEN}ping -c 4 127.0.0.1${RESET}"
echo "Test the local loopback interface."
echo -e "${GREEN}ping -c 4 8.8.8.8${RESET}"
echo "Test connectivity to Google DNS by IP."
read -n1 -s -r -p "Press any key to continue..."
echo;echo
# SSH Troubleshooting Guide
echo;echo
echo -e "${YELLOW}SSH Troubleshooting Guide${RESET}"
echo;echo
# Check if SSH is installed
echo -e "${YELLOW}Check if SSH is Installed${RESET}"
echo -e "${GREEN}ssh -V${RESET}"
echo "Check if SSH is installed and its version."
echo -e "${GREEN}sudo apt install openssh-server${RESET}"
echo "Install OpenSSH server if not installed."
read -n1 -s -r -p "Press any key to continue..."
echo;echo
# Check SSH service status
echo -e "${YELLOW}Check SSH Service Status${RESET}"
echo -e "${GREEN}sudo systemctl status ssh${RESET}"
echo "Check if the SSH service is running."
echo -e "${GREEN}sudo systemctl start ssh${RESET}"
echo "Start the SSH service if it is not running."
echo -e "${GREEN}sudo systemctl enable ssh${RESET}"
echo "Enable SSH service to start on boot."
read -n1 -s -r -p "Press any key to continue..."
echo;echo
# Test SSH connectivity locally
echo -e "${YELLOW}Test Local SSH Connectivity${RESET}"
echo -e "${GREEN}ssh localhost${RESET}"
echo "Test SSH connection to localhost to ensure the server is working."
read -n1 -s -r -p "Press any key to continue..."
echo;echo
# Check firewall for SSH
echo -e "${YELLOW}Check Firewall Rules for SSH${RESET}"
echo -e "${GREEN}sudo ufw status${RESET}"
echo "Check if the firewall allows SSH connections."
echo -e "${GREEN}sudo ufw allow 22/tcp${RESET}"
echo "Allow SSH traffic through the firewall (port 22, TCP)."
read -n1 -s -r -p "Press any key to continue..."
echo;echo
# Debug SSH connection
echo -e "${YELLOW}Debug SSH Connection${RESET}"
echo -e "${GREEN}ssh -v <username>@<server-ip>${RESET}"
echo "Enable verbose mode to debug SSH connection issues."
echo -e "${GREEN}sudo tail -f /var/log/auth.log${RESET}"
echo "Monitor authentication logs for SSH errors on the server."
read -n1 -s -r -p "Press any key to continue..."
echo;echo
# Restart Network Manager if Needed
echo -e "${YELLOW}Restart Network Manager${RESET}"
echo -e "${GREEN}sudo systemctl restart NetworkManager${RESET}"
echo "Ensure network services are running correctly."
read -n1 -s -r -p "Press any key to continue..."
echo;echo
# Driver and Hardware Issues
echo -e "${YELLOW}Driver and Hardware Issues${RESET}"
echo -e "${GREEN}lspci | grep Network${RESET}"
echo "Check if the network card is detected."
echo -e "${GREEN}dmesg | grep firmware${RESET}"
echo "Check for firmware or driver-related messages."
echo -e "${GREEN}sudo apt install --reinstall <driver-package>${RESET}"
echo "Reinstall network drivers (replace <driver-package> as needed)."
read -n1 -s -r -p "Press any key to continue..."
echo;echo
# DNS Issues
echo -e "${YELLOW}DNS Issues${RESET}"
echo -e "${GREEN}ping 8.8.8.8${RESET}"
echo "Test connectivity to Google DNS by IP."
echo -e "${GREEN}sudo nano /etc/resolv.conf${RESET}"
echo "Edit DNS settings manually and add Google's DNS servers:"
echo -e "${GREEN}nameserver 8.8.8.8${RESET}"
echo -e "${GREEN}nameserver 8.8.4.4${RESET}"
read -n1 -s -r -p "Press any key to continue..."
echo;echo
# Router or Network Configuration
echo -e "${YELLOW}Check Router Settings${RESET}"
echo "Ensure ICMP (ping) isn't blocked and MAC filtering isn't enabled."
read -n1 -s -r -p "Press any key to continue..."
echo;echo
# Routing Issues
echo -e "${YELLOW}Check Routing Tables${RESET}"
echo -e "${GREEN}ip route${RESET}"
echo "Check routing tables for potential issues with traffic paths."
read -n1 -s -r -p "Press any key to continue..."
echo;echo
echo -e "${YELLOW}Follow these steps to troubleshoot and resolve network issues.${RESET}"
echo "Note any errors and adjust configurations as needed."
echo;echo
