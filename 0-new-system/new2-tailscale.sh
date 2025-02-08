#!/bin/bash

set -e   # Exit immediately if a command exits with a non-zero status
set -x   # Show each command before execution

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root using sudo"
  exit 1
fi

# Check if Tailscale is installed
if command -V tailscale >/dev/null 2>&1; then
    echo "Tailscale is already installed. Bringing it up and displaying its IP."
    tailscale up   # Bring up Tailscale
    tailscale ip   # Display the Tailscale IP address
else
    # Install Tailscale
    apt update
    curl -fsSL https://tailscale.com/install.sh | sh
    apt update   # Update package list again to include Tailscale repository

    # Start and enable the Tailscale service
    systemctl enable --now tailscaled
    systemctl status tailscaled

    # Authenticate with Tailscale
    echo "Tailscale installation complete. Please authenticate your device."
    tailscale up   # Bring up Tailscale
    tailscale ip   # Display the Tailscale IP address
fi

# Detailed instructions for 2-way communication
cat <<EOF

Tailscale is installed and running on this system.

To set up two-way communication between this system and a remote system:

1. Install Tailscale on the remote system also using this script, or just the invoked tailscale script:
   curl -fsSL https://tailscale.com/install.sh | sh
   systemctl status tailscaled
   systemctl enable --now tailscaled
   Note the official documentation at:   https://tailscale.com/download

2. Authenticate both systems using "tailscale up" on each.

3. Once both systems are authenticated, check the Tailscale IP addresses for each system:
   - On this system: Run "tailscale ip" (e.g., 100.x.x.x).
   - On the remote system: Run "tailscale ip" to get its Tailscale IP.

4. Verify connectivity between the two systems:
   - From this system, you can ping the remote system's Tailscale IP (e.g., "ping 100.x.x.x").
   - From the remote system, you can ping this system's Tailscale IP.

5. Optional: Enable subnet routing or use MagicDNS for easier access to other devices on your networks.
   Refer to the official Tailscale documentation for advanced configurations: https://tailscale.com/kb.

tailscale status                         # Show current connection status and connected peers
tailscale netcheck                       # Check network status, NAT type, and connectivity issues
tailscale status --json | jq '.Peer'     # List all devices on the Tailscale network in JSON format
tailscale logout                         # Log out and disconnect from Tailscale
tailscale cert your-machine-name         # Get a TLS certificate for this machine (useful for HTTPS servers)
tailscale set --accept-dns=true          # Enable MagicDNS for easier hostname-based access
tailscale up --advertise-routes=192.168.1.0/24  # Advertise this device as a subnet router
tailscale up --exit-node=<device-name>   # Route all traffic through a specific Tailscale device (exit node)
tailscale down                           # Disable Tailscale on this machine
journalctl -u tailscaled --no-pager | tail -50  # Show last 50 lines of Tailscale logs


EOF

