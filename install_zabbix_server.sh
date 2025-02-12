#!/bin/bash

# Ensure script runs as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Switching to root user..."
    sudo su -c "bash $0"
    exit
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

# Ensure MySQL Server is installed
echo "Checking if MySQL Server is installed..."
if ! dpkg -l | grep -q mysql-server; then
    echo "MySQL Server is NOT installed. Installing now..."
    apt install -y mysql-server
    systemctl enable mysql
    systemctl start mysql
else
    echo "MySQL Server is already installed."
fi

# Verify MySQL is running
if ! systemctl is-active --quiet mysql; then
    echo "MySQL service is not running. Starting it now..."
    systemctl start mysql
    if ! systemctl is-active --quiet mysql; then
        echo "ERROR: MySQL failed to start. Check logs with 'sudo journalctl -xeu mysql'."
        exit 1
    fi
fi

# Create ~/.my.cnf file to store password
echo "[client]
user=root
password=${DB_PASS}" > ~/.my.cnf
chmod 600 ~/.my.cnf

# Create Zabbix database
mysql -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
mysql -e "CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';"
mysql -e "FLUSH PRIVILEGES;"

echo "Database setup complete!"

echo "Importing Zabbix database schema..."
zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u${DB_USER} -p"${DB_PASS}" ${DB_NAME}

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
