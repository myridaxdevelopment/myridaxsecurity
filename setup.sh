#!/bin/bash

# Update
apt install
apt upgrade
sudo apt autoremove

# Create a 24GB swap file
sudo fallocate -l 24G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Configure iptables rules to rate limit incoming L4 traffic (adjust as needed)
# This example rate limits incoming traffic to 50 Mbps on the eth0 interface
sudo iptables -A INPUT -i eth0 -p tcp --dport 80 -m conntrack --ctstate NEW -m limit --limit 50/s -j ACCEPT
sudo iptables -A INPUT -i eth0 -p tcp --dport 80 -m conntrack --ctstate NEW -j DROP

# Remove Docker container bandwidth limits
# To remove the bandwidth limits, you need to delete the qdisc for each container.
# Replace 'CONTAINER_UUID' with the UUID of your Docker container
docker exec CONTAINER_UUID tc qdisc del dev eth0 root

# Remove Docker container storage limits
# You can remove the custom storage options from the Docker daemon configuration.
sudo sed -i '/storage-opts/d' /etc/docker/daemon.json

# Restart the Docker daemon to apply the changes
sudo systemctl restart docker

# Configure iptables rate limiting to protect against DDoS attacks (adjust as needed)
# This example rate limits incoming traffic to 10 requests per second on port 80
sudo iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m limit --limit 10/s -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -j DROP

# Enable UFW and allow port 8443
sudo ufw enable
sudo ufw allow 8443

# Save the iptables rules and Docker daemon configuration to persist across reboots
sudo apt-get install iptables-persistent -y
sudo netfilter-persistent save
sudo netfilter-persistent reload

echo "Myridax Script execution completed. You can now proceed with the Pterodactyl Wings installation."
