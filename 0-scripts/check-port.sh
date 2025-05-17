#!/bin/bash

# Script to check port status and provide network information

# --- Configuration ---
NC_TIMEOUT=2 # Timeout in seconds for nc check

# --- Functions ---

# Function to display usage instructions
show_usage() {
  echo "Usage: ${0##*/} <PORT_NUMBER>"
  echo "       ${0##*/} -h | --help"
  echo
  echo "Description:"
  echo "  This script checks if a specific port is currently in use (listening) on the local machine."
  echo "  It uses 'ss', 'netstat', and 'lsof' to determine the port's state."
  echo "  Additionally, it attempts to identify the active firewall and provides general tips about network ports."
  echo
  echo "Checks performed for the specified port:"
  echo "  1. ss: Checks for listening TCP and UDP sockets."
  echo "  2. netstat: Checks for listening TCP and UDP sockets (legacy, but still useful)."
  echo "  3. lsof: Lists open files and can identify processes using the port (requires sudo for full visibility)."
  echo
  echo "Firewall Check:"
  echo "  - Detects if 'ufw' (Uncomplicated Firewall) is active and shows its status."
  echo "  - Detects if 'firewalld' is active and shows its status."
  echo "  - Provides commands to list 'iptables' rules if ufw/firewalld are not detected as primary."
  echo
  echo "Port Tips:"
  echo "  - Information on well-known, registered, and dynamic/private port ranges."
  echo "  - Brief explanation of TCP vs. UDP."
  echo "  - Security considerations for open ports."
  echo
  echo "Example:"
  echo "  $0 80   # Checks if port 80 is in use"
  echo
}

# Function to check firewall status
check_firewall_status() {
  echo "--- Firewall Status ---"
  ACTIVE_FIREWALL="None detected"

  # Check for ufw
  if command -v ufw > /dev/null; then
    if ufw status | grep -qw "Status: active"; then
      echo "[INFO] ufw (Uncomplicated Firewall) is active."
      ufw status verbose
      ACTIVE_FIREWALL="ufw"
      if sudo ufw status | grep -qw "$PORTALLOW"; then
         echo "[INFO] Port $PORT appears to be allowed by ufw."
      elif sudo ufw status | grep -qw "$PORTDENY"; then
         echo "[INFO] Port $PORT appears to be denied by ufw."
      else
         echo "[INFO] Port $PORT state in ufw is not explicitly 'allow' or 'deny' (could be default policy)."
      fi
    else
      echo "[INFO] ufw is installed but not active."
    fi
  else
    echo "[INFO] ufw is not installed."
  fi
  echo

  # Check for firewalld (if ufw is not the primary one)
  if [ "$ACTIVE_FIREWALL" != "ufw" ] && command -v firewall-cmd > /dev/null; then
    if systemctl is-active --quiet firewalld; then
      echo "[INFO] firewalld is active."
      echo "State: $(firewall-cmd --state)"
      ACTIVE_FIREWALL="firewalld"
      # Check if the port is open in the default zone (common scenario)
      # You might need to specify a zone if you use multiple zones
      if firewall-cmd --list-ports --zone=$(firewall-cmd --get-default-zone) 2>/dev/null | grep -qw "$PORT/tcp" || \
         firewall-cmd --list-ports --zone=$(firewall-cmd --get-default-zone) 2>/dev/null | grep -qw "$PORT/udp"; then
        echo "[INFO] Port $PORT appears to be allowed in the default firewalld zone."
      else
        echo "[INFO] Port $PORT does not appear to be explicitly allowed in the default firewalld zone."
        echo "       (Check 'firewall-cmd --list-all' or specific zones if used)"
      fi
    else
      echo "[INFO] firewalld is installed but not active."
    fi
  elif [ "$ACTIVE_FIREWALL" != "ufw" ]; then
    echo "[INFO] firewalld is not installed or not managed by systemd."
  fi
  echo

  # Information for iptables (often the underlying mechanism)
  if [ "$ACTIVE_FIREWALL" = "None detected" ]; then
    echo "[INFO] No high-level firewall management tool (ufw, firewalld) detected as active."
    echo "       You might be using iptables directly, or no firewall is active."
  fi
  echo "[INFO] To inspect raw iptables rules (these can be complex):"
  echo "  sudo iptables -L -n -v           # List all rules for all chains"
  echo "  sudo ip6tables -L -n -v          # List all IPv6 rules"
  echo "  sudo iptables -L INPUT -n -v     # List rules for the INPUT chain (common for incoming connections)"
  echo "  sudo iptables -S                 # Dump all rules in a parsable format"
  echo "  To check for a specific port (e.g., $PORT) in iptables INPUT chain:"
  echo "  sudo iptables -L INPUT -n -v --line-numbers | grep ':$PORT '"
  echo "  sudo iptables -L INPUT -n -v --line-numbers | grep 'dpt:$PORT '"
  echo
}

# Function to provide general port tips
general_port_tips() {
  echo "--- General Port Information & Tips ---"
  echo "[INFO] Port Number Ranges:"
  echo "  - Well-known ports (0-1023): Reserved for common services and applications (e.g., 80 for HTTP, 443 for HTTPS, 22 for SSH). Requires root privileges to bind to."
  echo "  - Registered ports (1024-49151): Can be registered by software vendors for specific applications."
  echo "  - Dynamic/Private ports (49152-65535): Used for temporary or private services; cannot be registered."
  echo
  echo "[INFO] TCP vs. UDP:"
  echo "  - TCP (Transmission Control Protocol): Connection-oriented, reliable, ordered delivery (e.g., HTTP, FTP, SSH). Establishes a connection before data transfer."
  echo "  - UDP (User Datagram Protocol): Connectionless, faster, less reliable, no guaranteed order (e.g., DNS, DHCP, VoIP, online gaming)."
  echo
  echo "[INFO] Why check ports?"
  echo "  - Troubleshooting: Ensure services are listening as expected."
  echo "  - Security Audits: Identify potentially unnecessary open ports that could be attack vectors."
  echo "  - Development: Verify applications are binding to the correct ports."
  echo
  echo "[INFO] Security Best Practices:"
  echo "  - Principle of Least Privilege: Only open ports that are absolutely necessary."
  echo "  - Firewall: Use a firewall (like ufw, firewalld, or iptables) to control inbound and outbound traffic. Deny by default, allow specific ports."
  echo "  - Regular Audits: Periodically check open ports and running services."
  echo "  - Keep Software Updated: Patch vulnerabilities in services listening on open ports."
  echo "  - Service Configuration: Configure services securely (e.g., use strong passwords, disable unused features)."
  echo
  echo "[TIP] If a port is 'free' but you expect a service to be on it:"
  echo "  1. Check if the service is running: 'systemctl status <service_name>' or 'ps aux | grep <process_name>'"
  echo "  2. Check service configuration files to ensure it's configured for the correct port and IP address (e.g., 0.0.0.0 or :: for all interfaces)."
  echo "  3. Check service logs for errors: 'journalctl -u <service_name>' or log files in /var/log/."
  echo
  echo "[TIP] If a port is 'in use' but you don't know by what:"
  echo "  - The 'sudo lsof -i :$PORT' command (run by this script) is the best way to identify the process."
  echo "  - 'sudo ss -tulnp | grep :$PORT' or 'sudo netstat -tulnp | grep :$PORT' can also show the Process ID (PID) and name."
  echo
}

# --- Main Script ---

# Check for help flag or no arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ -z "$1" ]; then
  show_usage
  exit 0
fi

# Validate if the input is a number
if ! [[ "$1" =~ ^[0-9]+$ ]]; then
  echo "Error: Port must be a number."
  show_usage
  exit 1
fi

PORT="$1"
PORTALLOW=" $PORT[/ ]*ALLOW IN" # Regex for ufw allow rule
PORTDENY=" $PORT[/ ]*DENY IN"   # Regex for ufw deny rule

echo "--- Checking Port $PORT ---"
echo

# 1. Check with ss
echo "[INFO] Checking with 'ss' utility..."
echo "Command: ss -tuln | grep -E \":$PORT\\b\""
if ss -tuln | grep -qE ":$PORT\b"; then
  echo "Status: Port $PORT is IN USE (listening according to ss)."
  echo "Details (ss -tulnp | grep :$PORT):"
  sudo ss -tulnp | grep ":$PORT\b" --color=never # Use sudo to see process names
else
  echo "Status: Port $PORT is FREE (not listening according to ss)."
fi
echo
# Explanation:
# ss: Socket statistics utility
# -t: Show TCP sockets
# -u: Show UDP sockets
# -l: Show listening sockets
# -n: Do not resolve service names (faster)
# -p: Show process using socket (requires sudo for all processes)
# grep -qE ":$PORT\b": Search quietly (-q) for the exact port number preceded by a colon and followed by a word boundary (\b) using extended regex (-E).
# If grep finds a match (exit status 0), the port is in use. Otherwise (exit status 1), it's free.

# 2. Check with netstat (legacy, but good for cross-check)
echo "[INFO] Checking with 'netstat' utility..."
if command -v netstat > /dev/null; then
  echo "Command: netstat -tuln | grep -E \":$PORT\\b\""
  if netstat -tuln | grep -qE ":$PORT\b"; then
    echo "Status: Port $PORT is IN USE (listening according to netstat)."
    echo "Details (netstat -tulnp | grep :$PORT):"
    sudo netstat -tulnp | grep ":$PORT\b" --color=never # Use sudo to see process names
  else
    echo "Status: Port $PORT is FREE (not listening according to netstat)."
  fi
else
  echo "[WARN] 'netstat' command not found. Skipping this check."
fi
echo
# Explanation:
# netstat: Network statistics
# -t, -u, -l, -n, -p: Similar to ss options.
# grep -qE ":$PORT\b": Similar to the ss grep.

# 3. Check with lsof
echo "[INFO] Checking with 'lsof' utility (may require sudo for full details)..."
echo "Command: sudo lsof -i :$PORT"
# We run lsof and capture output to display it, then check exit status
LSOF_OUTPUT=$(sudo lsof -i ":$PORT" 2>/dev/null)
if [ -n "$LSOF_OUTPUT" ]; then
  echo "Status: Port $PORT is IN USE (according to lsof)."
  echo "Details (sudo lsof -i :$PORT):"
  echo "$LSOF_OUTPUT"
else
  # Check exit status specifically, as no output doesn't always mean free if sudo fails for permission reasons
  # However, if lsof finds nothing, its exit status is 1 (or non-zero). If it finds something, it's 0.
  sudo lsof -i ":$PORT" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "Status: Port $PORT is IN USE (according to lsof, but no standard output captured - might be a kernel process or permissions issue)."
  else
    echo "Status: Port $PORT is FREE (according to lsof)."
    echo "       (If you expected it to be in use, ensure you have sudo privileges or try running 'sudo lsof -i :$PORT' manually)."
  fi
fi
# Explanation:
# lsof: Lists open files
# -i :$PORT: Filters for network files/sockets related to the specified port number.
# sudo: Often needed to see processes owned by other users (especially root) or kernel-level usage.
# > /dev/null: Redirects standard output to null if only checking existence. Here we capture output.
# If lsof finds anything (exit status 0), the port is in use. Otherwise (exit status non-zero), it's free.
echo

# 4. Attempt a basic connection test with nc (Netcat) - Optional, good for external view
# This checks if something is *actively accepting* connections, not just listening.
echo "[INFO] Attempting a quick connection test with 'nc' (Netcat)..."
if command -v nc > /dev/null; then
  # TCP Test
  echo "Command (TCP): nc -z -v -w $NC_TIMEOUT localhost $PORT"
  if nc -z -v -w $NC_TIMEOUT localhost "$PORT" 2>&1 | grep -q "succeeded"; then
    echo "Status (TCP): Port $PORT is OPEN and accepting TCP connections on localhost."
  else
    echo "Status (TCP): Port $PORT is CLOSED or not accepting TCP connections on localhost (or nc timeout)."
  fi
  # UDP Test (UDP is connectionless, so 'success' is harder to define with nc -z)
  # For UDP, nc -zu often sends a 0-byte packet. If no ICMP "port unreachable" comes back, it *might* be open.
  # This is less reliable than TCP.
  # echo "Command (UDP): nc -z -u -v -w $NC_TIMEOUT localhost $PORT"
  # if nc -z -u -v -w $NC_TIMEOUT localhost "$PORT" 2>&1 | grep -q "succeeded"; then # "succeeded" may not appear for UDP
  #   echo "Status (UDP): Port $PORT might be open for UDP on localhost (nc test is less definitive for UDP)."
  # else
  #   echo "Status (UDP): Port $PORT is likely closed for UDP on localhost (or nc timeout/no response)."
  # fi
else
  echo "[WARN] 'nc' (Netcat) command not found. Skipping connection test."
fi
echo

# --- Additional Information ---
check_firewall_status "$PORT" # Pass PORT to firewall check for specific rule hints
general_port_tips "$PORT"

exit 0
