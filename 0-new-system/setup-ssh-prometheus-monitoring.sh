#!/bin/bash

# Variables
PROMETHEUS_CONFIG="/etc/prometheus/prometheus.yml"
ALERT_RULES="/etc/prometheus/alert.rules.yml"
ALERTMANAGER_CONFIG="/etc/alertmanager/alertmanager.yml"
PROMETHEUS_SERVICE="prometheus"
ALERTMANAGER_SERVICE="alertmanager"

# Function to prompt user for email and other parameters
prompt_user() {
    read -p "Enter the email address for receiving alerts: " EMAIL
    read -p "Enter the SMTP smart host (default: smtp.gmail.com:587): " SMTP_SMARTHOST
    SMTP_SMARTHOST=${SMTP_SMARTHOST:-smtp.gmail.com:587}
    read -p "Enter the SMTP username (default: $EMAIL): " SMTP_USERNAME
    SMTP_USERNAME=${SMTP_USERNAME:-$EMAIL}
    read -s -p "Enter the SMTP password: " SMTP_PASSWORD
    echo
    read -p "Enter the alerting interval (default: 1m): " ALERT_INTERVAL
    ALERT_INTERVAL=${ALERT_INTERVAL:-1m}
}

# Function to install Prometheus
install_prometheus() {
    echo "Installing Prometheus..."
    sudo apt update && sudo apt install -y prometheus
}

# Function to install Alertmanager
install_alertmanager() {
    echo "Installing Alertmanager..."
    wget https://github.com/prometheus/alertmanager/releases/download/v0.25.0/alertmanager-0.25.0.linux-amd64.tar.gz -O /tmp/alertmanager.tar.gz
    tar -xvf /tmp/alertmanager.tar.gz -C /tmp/
    sudo mv /tmp/alertmanager-0.25.0.linux-amd64/alertmanager /usr/local/bin/
    sudo mv /tmp/alertmanager-0.25.0.linux-amd64/amtool /usr/local/bin/
    sudo mkdir -p /etc/alertmanager /var/lib/alertmanager
    sudo mv /tmp/alertmanager-0.25.0.linux-amd64/alertmanager.yml "$ALERTMANAGER_CONFIG"

    # Create a systemd service file for Alertmanager
    cat <<EOL | sudo tee /etc/systemd/system/alertmanager.service
[Unit]
Description=Alertmanager Service
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/alertmanager \
  --config.file="$ALERTMANAGER_CONFIG" \
  --storage.path="/var/lib/alertmanager"
Restart=always

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable alertmanager
    sudo systemctl start alertmanager
}

# Function to configure Prometheus for SSH monitoring
configure_prometheus() {
    echo "Configuring Prometheus for SSH monitoring..."

    # Add a job for SSH monitoring
    if ! grep -q "job_name: 'ssh_service'" "$PROMETHEUS_CONFIG"; then
        sudo sed -i '/scrape_configs:/a \
  - job_name: 'ssh_service'\
    static_configs:\
      - targets: ['localhost:9100']' "$PROMETHEUS_CONFIG"
    fi
}

# Function to create alerting rules
create_alert_rules() {
    echo "Creating alert rules for SSH service..."

    cat <<EOL | sudo tee "$ALERT_RULES"
group:
  name: ssh_service_alerts
  rules:
    - alert: SSHServiceDown
      expr: up{job="ssh_service"} == 0
      for: $ALERT_INTERVAL
      labels:
        severity: critical
      annotations:
        summary: "SSH service is down"
        description: "The SSH service on {{ $labels.instance }} is unreachable."
EOL

    # Update Prometheus configuration to load alert rules
    if ! grep -q "alerting:" "$PROMETHEUS_CONFIG"; then
        echo -e "alerting:\n  alertmanagers:\n    - static_configs:\n      - targets: ['localhost:9093']" | sudo tee -a "$PROMETHEUS_CONFIG"
    fi

    if ! grep -q "rule_files:" "$PROMETHEUS_CONFIG"; then
        echo -e "rule_files:\n  - $ALERT_RULES" | sudo tee -a "$PROMETHEUS_CONFIG"
    fi
}

# Function to configure alertmanager
configure_alertmanager() {
    echo "Configuring Alertmanager to send emails..."

    cat <<EOL | sudo tee "$ALERTMANAGER_CONFIG"
global:
  smtp_smarthost: '$SMTP_SMARTHOST'
  smtp_from: 'alertmanager@$EMAIL'
  smtp_auth_username: '$SMTP_USERNAME'
  smtp_auth_password: '$SMTP_PASSWORD'
  smtp_require_tls: true

route:
  receiver: 'email-alert'

receivers:
  - name: 'email-alert'
    email_configs:
      - to: '$EMAIL'
EOL

    # Restart Alertmanager
    sudo systemctl restart "$ALERTMANAGER_SERVICE"
}

# Prompt user for configuration
prompt_user

# Check if Prometheus is installed
if ! dpkg -l | grep -q prometheus; then
    install_prometheus
fi

# Check if Alertmanager is installed
if ! command -v alertmanager &> /dev/null; then
    install_alertmanager
fi

# Configure Prometheus
configure_prometheus

# Create alert rules
create_alert_rules

# Configure Alertmanager
configure_alertmanager

# Restart Prometheus to apply changes
sudo systemctl restart "$PROMETHEUS_SERVICE"

# Print status
echo "Prometheus and Alertmanager have been configured to monitor SSH and send alerts to $EMAIL."

