#!/bin/bash

# Ensure the script runs as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root or use sudo."
    exit 1
fi

echo "Installing Zabbix Server on Ubuntu 24.04..."

# Define database credentials
DB_NAME="zabbix"
DB_USER="zabbix"
DB_PASS="password"  # Change this to a secure password

# Install Zabbix repository
wget https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu24.04_all.deb -O /tmp/zabbix-release.deb
dpkg -i /tmp/zabbix-release.deb
apt update

# Install Zabbix Server, Frontend, and Agent
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

# Install MySQL Server if not already installed
if ! command -v mysql &> /dev/null; then
    echo "MySQL Server is not installed. Installing..."
    apt install -y mysql-server
    systemctl enable mysql
    systemctl start mysql
fi

echo "Creating Zabbix database..."
mysql -uroot -p <<MYSQL_SCRIPT
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Import initial schema and data
echo "Importing Zabbix database schema..."
zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u${DB_USER} -p${DB_PASS} ${DB_NAME}

# Disable log_bin_trust_function_creators after importing
mysql -uroot -p <<MYSQL_SCRIPT
SET GLOBAL log_bin_trust_function_creators = 0;
MYSQL_SCRIPT

# Configure Zabbix server with database password
sed -i "s/^# DBPassword=/DBPassword=${DB_PASS}/" /etc/zabbix/zabbix_server.conf

# Restart and enable services
echo "Starting and enabling Zabbix services..."
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2

echo "Zabbix Server installation and setup complete!"
