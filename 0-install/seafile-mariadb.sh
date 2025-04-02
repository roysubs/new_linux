#!/bin/bash

set -e

# Ensure we are running as root (only if necessary)
if [[ $EUID -ne 0 ]]; then
    echo "Elevation required; rerunning as sudo..."
    exec sudo bash "$0" "$@"
fi

# Function to show installation details
show_details() {
    echo "This script will install and configure Seafile on Debian."
    echo "It will:"
    echo "- Install necessary dependencies including Python3 and MariaDB."
    echo "- Create a dedicated 'seafile' user for security."
    echo "- Install and configure MariaDB for Seafile."
    echo "- Set up an Nginx reverse proxy to serve Seafile."
    echo "- Download, extract, and initialize Seafile."
    echo "- Configure and start the Seafile and Seahub services."
    echo "- Open required firewall ports (80, 443, 8000, 8082) if UFW is enabled."
    echo ""
    echo "Estimated disk space usage: ~500MB to 1.5GB"
    echo "Do you want to continue? (y/n)"
}

# Check if --force is provided
if [[ "$1" != "--force" ]]; then
    show_details
    read -p "This script will install Seafile and required dependencies. Continue? (y/N): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Installation aborted."
        exit 1
    fi
fi


# Variables
SEAFILE_DIR="/opt/seafile"
NGINX_CONF="/etc/nginx/sites-available/seafile"
START_TIME=$(date +%s)

# Function to check disk usage
check_disk_usage() {
    echo "Disk usage before/after installation:"
    df -h / | awk 'NR==1 || /\//'
}

check_disk_usage

# Update system
apt update && apt upgrade -y

# Install dependencies
apt install -y python3 python3-setuptools python3-pip \
               python3-mysqldb python3-ldap python3-urllib3 \
               python3-requests python3-pil nginx mariadb-server mariadb-client ufw

# Create Seafile user
if ! id "seafile" &>/dev/null; then
    adduser --disabled-login --gecos "Seafile User" seafile
fi

# Secure MariaDB
mysql_secure_installation

# Set up database
mysql -u root -p <<EOF
CREATE DATABASE seafiledb CHARACTER SET = 'utf8mb4';
CREATE USER 'seafile'@'localhost' IDENTIFIED BY 'StrongPasswordHere';
GRANT ALL PRIVILEGES ON seafiledb.* TO 'seafile'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# Install Seafile
mkdir -p "$SEAFILE_DIR" && cd "$SEAFILE_DIR"
wget https://download.seadrive.org/seafile-server_8.0.2_x86-64.tar.gz

tar -zxvf seafile-server_8.0.2_x86-64.tar.gz
cd seafile-server-8.0.2

# Configure Seafile
echo "[database]
type = mysql
host = 127.0.0.1
port = 3306
user = seafile
password = StrongPasswordHere
db_name = seafiledb
connection_charset = utf8" > seafile-data/seafile.conf

# Setup Seafile
touch seafile-data/seahub_settings.py
echo "DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'seafiledb',
        'USER': 'seafile',
        'PASSWORD': 'StrongPasswordHere',
        'HOST': '127.0.0.1',
        'PORT': '3306',
    }
}" > seafile-data/seahub_settings.py

./setup-seafile-mysql.sh auto
./seafile.sh start
./seahub.sh start

# Configure Nginx
echo "server {
listen 80;
server_name your_domain;

location / {
    proxy_pass http://127.0.0.1:8000;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Host \$server_name;
    proxy_set_header X-Forwarded-Proto \$scheme;
}

location /seafhttp {
    rewrite ^/seafhttp(.*)\$ \$1 break;
    proxy_pass http://127.0.0.1:8082;
    client_max_body_size 0;
}

location /media {
    root /opt/seafile/seafile-server-latest/seahub;
}
}" > "$NGINX_CONF"

ln -s "$NGINX_CONF" /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Configure firewall
ufw allow 80,443/tcp
ufw allow 8000/tcp
ufw allow 8082/tcp
ufw enable

# Display results
check_disk_usage

END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))
echo "Installation completed in $((ELAPSED_TIME / 60)) minutes and $((ELAPSED_TIME % 60)) seconds."

