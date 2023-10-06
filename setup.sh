#!/bin/bash

# Create a 24GB swap file
sudo fallocate -l 24G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Configure iptables rules to rate limit incoming L4 traffic (adjust as needed)
# This example rate limits incoming traffic to 50 Mbps on the eth0 interface
sudo iptables -A INPUT -i eth0 -p tcp --dport 80 -m conntrack --ctstate NEW -m limit --limit 50/s -j ACCEPT
sudo iptables -A INPUT -i eth0 -p tcp --dport 80 -m conntrack --ctstate NEW -j DROP

# Set a 40GB storage limit for newly created Docker containers
echo '{"storage-opts": ["size=40G"]}' | sudo tee /etc/docker/daemon.json

# Limit the network bandwidth of Docker containers to 50 Mbps (adjust as needed)
# Replace 'CONTAINER_UUID' with the UUID of your Docker container
docker exec CONTAINER_UUID tc qdisc add dev eth0 root tbf rate 50mbit burst 10kbit latency 50ms

# Configure iptables rate limiting to protect against DDoS attacks (adjust as needed)
# This example rate limits incoming traffic to 10 requests per second on port 80
sudo iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m limit --limit 10/s -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -j DROP

# Restart the Docker daemon to apply the new configuration
sudo systemctl restart docker

# UFW Firewalls to allow 8443
ufw enable
ufw allow 8443

# Save the iptables rules and Docker daemon configuration to persist across reboots
sudo apt-get install iptables-persistent -y
sudo netfilter-persistent save
sudo netfilter-persistent reload

echo "Myridax Script execution completed. You can now proceed with the Pterodactyl Wings installation."
