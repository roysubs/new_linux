#!/bin/bash

# Function to show installation details
show_details() {
    echo "This script will install and configure FileRun on Debian."
    echo "It will:"
    echo "- Install Apache, PHP, and MariaDB."
    echo "- Download and set up FileRun."
    echo "- Configure Apache to run FileRun on port 8081."
    echo "- Create a MariaDB database for FileRun."
    echo ""
    echo "Estimated disk space usage: ~500MB to 1GB"
    echo "Do you want to continue? (y/n)"
}

# Check if --force is provided
if [[ "$1" != "--force" ]]; then
    show_details
    read -r choice
    if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
        echo "Installation cancelled."
        exit 1
    fi
fi

# Record start time
start_time=$(date +%s)

# Record initial disk usage
initial_size=$(df --output=used / | tail -n 1)

# Update system and install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y apache2 php libapache2-mod-php php-mysql php-gd php-xml php-mbstring php-json php-zip php-curl php-bz2 php-intl mariadb-server wget

# Configure Apache to listen on port 8081 for FileRun
echo "Listen 8081" | sudo tee -a /etc/apache2/ports.conf

# Download and install FileRun
cd /var/www/html
sudo wget https://filerun.com/download-latest
sudo tar -xvzf download-latest -C /var/www/html
sudo mv filerun /var/www/html/filerun
sudo chown -R www-data:www-data /var/www/html/filerun

# Create a new Apache config file for FileRun (to run on port 8081)
sudo bash -c 'cat > /etc/apache2/sites-available/filerun.conf <<EOF
<VirtualHost *:8081>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/filerun
    ServerName localhost

    <Directory /var/www/html/filerun>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF'

# Enable the new site and Apache modules
sudo a2ensite filerun.conf
sudo a2enmod rewrite
sudo systemctl restart apache2

# Secure MariaDB and set up FileRun database
sudo mysql_secure_installation

# Log in to MariaDB and create the database for FileRun
sudo mysql -u root -p <<EOF
CREATE DATABASE filerun;
CREATE USER 'filerunuser'@'localhost' IDENTIFIED BY 'yourpassword';
GRANT ALL PRIVILEGES ON filerun.* TO 'filerunuser'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# Record end time
end_time=$(date +%s)

# Record final disk usage
final_size=$(df --output=used / | tail -n 1)

# Calculate space used
space_used=$((final_size - initial_size))
space_used_mb=$((space_used / 1024)) # Convert to MB

# Calculate time taken
elapsed_time=$((end_time - start_time))
elapsed_min=$((elapsed_time / 60))
elapsed_sec=$((elapsed_time % 60))

# Output results
echo ""
echo "FileRun installation complete!"
echo "You can now access FileRun at: http://your-server-ip:8081/filerun"
echo "--------------------------------------------"
echo "Installation Time: ${elapsed_min} min ${elapsed_sec} sec"
echo "Disk Space Used: ${space_used_mb} MB"
echo "--------------------------------------------"

