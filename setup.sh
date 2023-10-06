#!/bin/bash

# Version of the script
SCRIPT_VERSION="1.2"

# Log file for script output
LOG_FILE="/var/log/myridax_script.log"

# Function to add Fail2Ban rules
configure_fail2ban() {
  sudo apt-get update
  sudo apt-get install fail2ban -y

  # Create a custom jail.local file for Fail2Ban
  sudo tee /etc/fail2ban/jail.local > /dev/null <<EOL
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
findtime = 600
bantime = 3600

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 6
findtime = 600
bantime = 3600
EOL

  # Restart Fail2Ban to apply the new configuration
  sudo service fail2ban restart
}

# Update
sudo apt update
sudo apt upgrade 
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

# Block specific ports using iptables
blocked_ports=(465 25 26 995 143 22 110 993 587 5222 5269 5443)
for port in "${blocked_ports[@]}"; do
  sudo iptables -I FORWARD 1 -p tcp -m tcp --dport "$port" -j DROP
  sudo iptables -I FORWARD 1 -p udp -m udp --dport "$port" -j DROP
done

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
sudo ufw allow 8443/tcp

# Save the iptables rules and Docker daemon configuration to persist across reboots
sudo apt-get install iptables-persistent -y
sudo netfilter-persistent save
sudo netfilter-persistent reload

# Install and configure Fail2Ban
configure_fail2ban

# Prompt user to run the Pterodactyl Wings installation
read -p "Do you want to run the Pterodactyl Wings installation now? (Y/N): " INSTALL_WINGS
if [ "$INSTALL_WINGS" == "Y" ] || [ "$INSTALL_WINGS" == "y" ]; then
  # Run the Pterodactyl Wings installation script with logging
  echo "Installing Pterodactyl Wings..." | tee -a "$LOG_FILE"
  bash <(curl -s https://pterodactyl-installer.se/) 2>&1 | tee -a "$LOG_FILE"
  echo "Pterodactyl Wings installation completed." | tee -a "$LOG_FILE"
else
  echo "Pterodactyl Wings installation skipped. You can run it manually when ready." | tee -a "$LOG_FILE"
fi

# ASCII Completed
echo -e "\e[34m╭─────────────────────────────────────────────────────╮\e[0m" | tee -a "$LOG_FILE"
echo -e "\e[34m│                                                     │\e[0m" | tee -a "$LOG_FILE"
echo -e "\e[34m│  \e[0mMyridax Security » Script Version: $SCRIPT_VERSION installed!\e[34m  │\e[0m" | tee -a "$LOG_FILE"
echo -e "\e[34m│  \e[0mThank you for using this script!\e[34m          │\e[0m" | tee -a "$LOG_FILE"
echo -e "\e[34m│  \e[0mThis has been coded and developed by Amir Kadir\e[34m   │\e[0m" | tee -a "$LOG_FILE"
echo -e "\e[34m│                                                     │\e[0m" | tee -a "$LOG_FILE"
echo -e "\e[34m╰─────────────────────────────────────────────────────╯\e[0m" | tee -a "$LOG_FILE"

echo "Myridax Script execution completed." | tee -a "$LOG_FILE"
