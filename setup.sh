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

# Set a 40GB storage limit and 50Mbps network bandwidth limit for all Docker containers in the directory
DIRECTORY="/var/lib/pterodactyl/volumes/*"
for CONTAINER_UUID in $(docker ps -q); do
  docker exec $CONTAINER_UUID tc qdisc add dev eth0 root tbf rate 50mbit burst 10kbit latency 50ms
  docker update --storage-opt size=40G $CONTAINER_UUID
done

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

# Prompt user to run Pterodactyl Wings installation
read -p "Do you want to run the Pterodactyl Wings installation now? (Y/N): " INSTALL_WINGS
if [ "$INSTALL_WINGS" == "Y" ] || [ "$INSTALL_WINGS" == "y" ]; then
  # Run the Pterodactyl Wings installation script
  bash <(curl -s https://pterodactyl-installer.se/)
else
  echo "Pterodactyl Wings installation skipped. You can run it manually when ready."
fi

echo "Myridax Script execution completed."
