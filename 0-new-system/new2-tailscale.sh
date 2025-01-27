#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Show each command before execution
set -x

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root using sudo"
  exit 1
fi

# Update package list and install prerequisites
apt update
curl -fsSL https://tailscale.com/install.sh | sh
apt update   # Update package list again to include Tailscale repository

# Start and enable the Tailscale service
systemctl enable --now tailscaled
systemctl status tailscaled

# Authenticate with Tailscale
echo "Tailscale installation complete. Please authenticate your device."
tailscale up

# Display the Tailscale IP address
tailscale ip

# Detailed instructions for 2-way communication
cat <<EOF

Tailscale has been successfully installed and configured on this system.

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

EOF

