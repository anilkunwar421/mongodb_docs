#!/bin/bash

# Prompt user for input
read -p "Enter your or your company email: " EMAIL
read -p "Enter domain for this replica: " DOMAIN

# Get the server's public IP address
SERVER_IP=$(curl -s ipinfo.io/ip)

# Perform a DNS lookup to get the IP address that the domain points to
DOMAIN_IP=$(nslookup $DOMAIN | awk '/^Address: / { print $2 ; exit }')

# Check if the domain IP matches the server IP
if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    echo "Error: Domain is not pointed to this server's IP ($SERVER_IP). Please update DNS settings and try again."
    exit 1
fi

# Install Certbot and issue certificate
sudo apt-get install certbot python3-certbot-nginx --yes
sudo ufw allow 80/tcp
sudo certbot certonly --standalone --preferred-challenges http -d $DOMAIN --non-interactive --agree-tos --email $EMAIL
cat /etc/letsencrypt/live/$DOMAIN/privkey.pem /etc/letsencrypt/live/$DOMAIN/fullchain.pem | sudo tee /etc/ssl/$DOMAIN.pem
echo "Updating the /etc/mongod.conf file with domain name $DOMAIN..."
sudo sed -i "/^net:/a \ \ tls:\n\ \ \ \ mode: requireTLS\n\ \ \ \ certificateKeyFile: /etc/ssl/$DOMAIN.pem" /etc/mongod.conf
sudo sed -i "/^net:/a \ \ maxIncomingConnections: 999999" /etc/mongod.conf
sudo systemctl restart mongod
echo "Setting up automatic renewal of the certificate..."
#create update_mongo_certs.sh file
cat <<EOF > update_mongo_certs.sh
#!/bin/bash

# Combine private key and full chain into one PEM file for MongoDB
cat /etc/letsencrypt/live/$DOMAIN/privkey.pem /etc/letsencrypt/live/$DOMAIN/fullchain.pem > /etc/ssl/$DOMAIN.pem

# Set the permissions so only the root user can read the combined PEM file
chmod 600 /etc/ssl/$DOMAIN.pem

# Restart MongoDB to apply the new certificates
systemctl restart mongod

# Log an update message
echo "MongoDB certificates updated and service restarted."

# Exit the script
exit 0
EOF
chmod +x update_mongo_certs.sh
(crontab -l 2>/dev/null; echo "17 3,15 * * * certbot renew --noninteractive --deploy-hook \"/root/update_mongo_certs.sh\"") | crontab -
systemctl restart cron
