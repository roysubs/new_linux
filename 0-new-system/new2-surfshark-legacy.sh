#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Variables ---
# Common ports often used for web interfaces (HTTP/HTTPS and common alternates)
COMMON_WEB_PORTS="80 443 8000 8080 8443 3000 4533 9091 8888 4001 3333 9443 61208 5201" # Added ports from your example that weren't there

# Array to store potentially web services for later display
declare -a potential_web_services_list

# --- Functions ---

# Check if the script is run as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "🚨 Error: This script needs to run with root privileges to list all processes and ports."
        echo "Please run: sudo $0"
        exit 1
    fi
}

# Check if lsof and curl are installed, and suggest installing if not
check_dependencies() {
    echo "🔎 Checking for required commands: lsof, curl"
    if ! command -v lsof &> /dev/null; then
        echo "🚨 Error: 'lsof' command not found."
        echo "Please install it using: sudo apt update && sudo apt install lsof"
        exit 1
    fi
     if ! command -v curl &> /dev/null; then
        echo "🚨 Error: 'curl' command not found."
        echo "Please install it using: sudo apt update && sudo apt install curl"
        exit 1
    fi
    echo "✅ Required commands found."
    echo
}

# Attempt to connect to a port via HTTP/S and get the Server header
# Args: $1 = IP Address/Hostname, $2 = Port
get_web_service_header() {
    local address="$1"
    local port="$2"
    local header=""
    local curl_target="$address"

    # Use localhost if the address is a wildcard or loopback for curl from the server itself
    if [ "$address" == "0.0.0.0" ] || [ "$address" == "[::]" ] || [ "$address" == "127.0.0.1" ] || [ "$address" == "::1" ]; then
        curl_target="localhost"
    fi

    # Try HTTPS first (more secure and common for web interfaces)
    header=$(curl -I -s -L -m 5 "https://$curl_target:$port" 2>/dev/null | grep -i '^Server:')

    # If HTTPS failed or no Server header found, try HTTP
    if [ -z "$header" ]; then
        header=$(curl -I -s -L -m 5 "http://$curl_target:$port" 2>/dev/null | grep -i '^Server:')
    fi

    if [ -n "$header" ]; then
        # Extract the header value
        echo "$header" | sed 's/^Server: //i' | tr -d '\r'
    else
        # Check if curl could connect at all (suppressed by -s, need verbose output redirected to dev/null)
        # We can re-run curl with -v to see if it connected, but that's noisy.
        # A simpler approach is to just report if the Server header was found or not.
        # If header is empty, it means either curl failed or no Server header was returned.
        # It's hard to distinguish perfectly without more complex curl logic or error checking.
        # Let's just say 'Server header not found or service not HTTP/S'.
         echo "Server header not found or service not HTTP/S"
    fi
}


# Find and list services listening on TCP ports, highlighting potential web ports
find_listening_services() {
    echo "🔎 Searching for services listening on TCP ports..."
    echo "   (Highlighting ports commonly used for web interfaces and checking Server header)"
    echo

    # Use lsof as before, filter for LISTEN, and extract command, PID, and address:port.
    # Store the raw output lines for later processing.
    lsof_output=$(sudo lsof -iTCP -P -n | grep LISTEN)

    # Process output line by line to categorize ports
    # Skip header (awk NR>1)
    listening_services=$(echo "$lsof_output" | awk 'NR>1 { command=$1; pid=$2; name=$9; sub(/ \(LISTEN\)$/, "", name); print command, pid, name }')

    if [ -z "$listening_services" ]; then
        echo "✅ No services found listening on TCP ports."
        # Return early as there's nothing to list or categorize
        return
    else
        echo "Found the following services listening on TCP ports:"
        echo "---------------------------------------------------------------------------------------------------"
        printf "%-20s %-10s %-25s %-20s %s\n" "COMMAND" "PID" "LISTEN ADDRESS:PORT" "CATEGORY" "SERVER INFO"
        echo "---------------------------------------------------------------------------------------------------"

        # Reset the potential web services list
        potential_web_services_list=()

        echo "$listening_services" | while read -r command pid address_port; do
            # Extract just the port number
            port=$(echo "$address_port" | awk -F: '{ print $NF }')
            # Extract just the address part
            address=$(echo "$address_port" | sed 's/:.*//')

            category="Other TCP Service"
            server_info="" # Initialize server info

            # Check if the port is a positive integer before comparison and curl attempt
            if [[ "$port" =~ ^[0-9]+$ ]]; then
                if [ "$port" -eq 80 ] || [ "$port" -eq 443 ]; then
                    category="Likely Web (HTTP/S)"
                    server_info=$(get_web_service_header "$address" "$port")
                # Check against the list of common web ports
                elif echo "$COMMON_WEB_PORTS" | grep -w "$port" &> /dev/null; then
                     category="Potentially Web"
                     server_info=$(get_web_service_header "$address" "$port")
                     # Store this entry for later, prepend port for sorting
                     # Include server_info in stored list for redisplay
                     potential_web_services_list+=("$port|$command|$pid|$address_port|$server_info")
                fi
            fi

            # If server_info is still empty (not a likely/potential web port), display a placeholder
             if [ -z "$server_info" ] && ([ "$category" == "Likely Web (HTTP/S)" ] || [ "$category" == "Potentially Web" ]); then
                server_info="Checking..." # Should ideally not happen if get_web_service_header works
            elif [ -z "$server_info" ]; then
                 server_info="-" # Placeholder for non-web services
            fi


            printf "%-20s %-10s %-25s %-20s %s\n" "$command" "$pid" "$address_port" "$category" "$server_info"
        done
        echo "---------------------------------------------------------------------------------------------------"
        echo
        echo "ℹ️ Explanation:"
        echo "  - COMMAND: The name of the process."
        echo "  - PID: The Process ID of the service."
        echo "  - LISTEN ADDRESS:PORT: The IP address and port the service is listening on."
        echo "    - '0.0.0.0' or '[::]' means listening on all available network interfaces (accessible externally)."
        echo "    - '127.0.0.1' or '::1' means listening only on the local machine (not accessible externally)."
        echo "  - CATEGORY: An estimation based on the port number."
        echo "    - 'Likely Web (HTTP/S)': Standard web ports."
        echo "    - 'Potentially Web': Ports commonly used for web interfaces, but could be something else."
        echo "    - 'Other TCP Service': Ports not commonly associated with web interfaces."
        echo "  - SERVER INFO: The value of the HTTP 'Server' header if detected via curl, or an indicator if not."
        echo
        echo "💡 How to Investigate 'Other TCP Service' Ports:"
        echo "  - Consult the documentation for the COMMAND/process name listed to determine what service it is and what port(s) it uses."
    fi

    echo "Search complete."
}

# --- Main Script Execution ---

check_root
check_dependencies # Check for curl as well now
find_listening_services # This populates the potential_web_services_list array

# After the main output, display the filtered list if not empty
if [ ${#potential_web_services_list[@]} -gt 0 ]; then
    echo
    echo "--- Potentially Web Services (Sorted by Port) ---"
    echo "---------------------------------------------------------------------------------------------------"
    printf "%-20s %-10s %-25s %-20s %s\n" "COMMAND" "PID" "LISTEN ADDRESS:PORT" "CATEGORY" "SERVER INFO"
    echo "---------------------------------------------------------------------------------------------------"

    # Sort the array numerically by the first field (port) using '|' as delimiter
    # Then loop through the sorted output and print the original fields
    printf "%s\n" "${potential_web_services_list[@]}" | sort -n -t'|' -k1 | while IFS='|' read -r port command pid address_port server_info; do
         printf "%-20s %-10s %-25s %-20s %s\n" "$command" "$pid" "$address_port" "Potentially Web" "$server_info" # Category is always "Potentially Web" here
    done
    echo "---------------------------------------------------------------------------------------------------"
fi

echo "Script finished."
