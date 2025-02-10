#!/bin/bash

# Ensure script runs as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Switching to root user..."
    sudo su -c "bash $0"
    exit
fi

echo "Installing Zabbix Agent on Ubuntu 24.04..."

# Install Zabbix repository
wget https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu24.04_all.deb -O /tmp/zabbix-release.deb
dpkg -i /tmp/zabbix-release.deb
apt update

# Install Zabbix Agent
apt install -y zabbix-agent

# Ensure MySQL Server is installed (Optional for Zabbix Agent)
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

# Start and enable Zabbix Agent service
echo "Starting and enabling Zabbix Agent..."
systemctl restart zabbix-agent
systemctl enable zabbix-agent

echo "Zabbix Agent installation and setup complete!"
