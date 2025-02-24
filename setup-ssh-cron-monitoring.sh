#!/bin/bash

# If SSH on a remote system goes down, this cron job will restart the service

# Alternative ways to ensure access to the system:
# 1. Enable SSH KeepAlive in the SSH server configuration (/etc/ssh/sshd_config)
#    to keep the SSH connection alive and detect hangs.
#    ClientAliveInterval 60
#    ClientAliveCountMax 3
#    This polls the client every 60 seconds; if no response after 3 tries, it closes the connection.
# 2. Set Up Monitoring with Nagios, Zabbix, or Prometheus to monitor the SSH service and get alerts.
# 3. Alternative Services to SSH:
#    Mosh (Mobile Shell): A remote terminal application that works well with intermittent connections.
#    Telnet: Although less secure, it can be used as a backup method if SSH fails.
#    VPN: Set up a VPN like OpenVPN or WireGuard for secure remote access to your network.

# Create a script to run in cron to check SSH service status
cat <<'EOF' > /usr/local/bin/check_ssh.sh
#!/bin/bash

# Check if SSH service is active
if ! systemctl is-active --quiet ssh; then
    echo "SSH service is down. Restarting SSH service..."
    systemctl restart ssh
else
    echo "SSH service is running."
fi
EOF

# Make the script executable
chmod +x /usr/local/bin/check_ssh.sh

# Create a cron job to run the script at intervals
# (crontab -l 2>/dev/null; echo "0 * * * * /usr/local/bin/check_ssh.sh") | crontab -   # every hour
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/check_ssh.sh") | crontab -   # every 5 minutes
echo "Cron job created to check SSH service."

