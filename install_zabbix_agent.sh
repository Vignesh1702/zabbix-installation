#!/bin/bash

# Ensure script runs as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Switching to root user..."
    sudo su -c "bash $0"
    exit
fi

echo "Installing Zabbix agent on Ubuntu 24.04..."

wget https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu24.04_all.deb -O /tmp/zabbix-release.deb
dpkg -i /tmp/zabbix-release.deb

apt update

apt install -y zabbix-agent

systemctl restart zabbix-agent
systemctl enable zabbix-agent

echo "Zabbix agent installation and setup complete!"
