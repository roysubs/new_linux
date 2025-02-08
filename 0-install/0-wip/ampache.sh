#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!" 
    exit 1
fi

# Update package lists and install prerequisites
echo "Updating package lists..."
apt update -y

echo "Installing required packages..."
# Install MariaDB instead of MySQL
apt install -y mariadb-server apache2 php libapache2-mod-php php-mysqli php-mbstring php-curl php-xml php-zip git unzip ffmpeg

# Set up MySQL/MariaDB database (use MariaDB here)
echo "Setting up MariaDB database for Ampache..."
MYSQL_ROOT_PASSWORD="ampache_root_password"
MYSQL_USER="ampache_user"
MYSQL_PASSWORD="ampache_password"
MYSQL_DATABASE="ampache_db"

# Start MariaDB service
systemctl start mariadb
systemctl enable mariadb

# Secure MariaDB (optionally set root password, remove test db, etc.)
mysql_secure_installation

mysql -e "CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE;"
mysql -e "CREATE USER IF NOT EXISTS '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Install Ampache
echo "Cloning Ampache from GitHub..."
cd /var/www/
git clone https://github.com/ampache/ampache.git ampache

# Set proper permissions
echo "Setting up permissions..."
chown -R www-data:www-data /var/www/ampache
chmod -R 755 /var/www/ampache

# Set up Apache VirtualHost for Ampache
echo "Configuring Apache VirtualHost..."
cat > /etc/apache2/sites-available/ampache.conf <<EOL
<VirtualHost *:8090>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/ampache
    DirectoryIndex index.php

    <Directory /var/www/ampache>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL

# Enable the site and rewrite module
a2ensite ampache.conf
a2enmod rewrite

# Restart Apache to apply changes
systemctl restart apache2

# Set up Ampache configuration
echo "Setting up Ampache configuration..."
cd /var/www/ampache
cp config/ampache.cfg.sample config/ampache.cfg
sed -i "s/^\$config\['db_user'\] = 'root';/\$config\['db_user'\] = '$MYSQL_USER';/" config/ampache.cfg
sed -i "s/^\$config\['db_pass'\] = '';/\$config\['db_pass'\] = '$MYSQL_PASSWORD';/" config/ampache.cfg
sed -i "s/^\$config\['db_name'\] = 'ampache';/\$config\['db_name'\] = '$MYSQL_DATABASE';/" config/ampache.cfg

# Run Ampache installer
echo "Running Ampache installer..."
cd /var/www/ampache/setup
php install.php

# Disable plugin setup for now as it's not available
echo "Skipping plugin setup for online streaming music."

# Restart Apache after installation
systemctl restart apache2

# Allow access to the correct port (8090) in firewall (if needed)
echo "Configuring firewall (if UFW is used)..."
ufw allow 8090/tcp

# Final message
echo "Ampache is now installed and running at http://<server-ip>:8090"
echo "You can access it remotely by connecting to this URL."

