#!/bin/bash

# Prompt user for input
read -p "Enter Your or your company country code (eg: US, CA): " COUNTRY_CODE
read -p "Enter Your or your company state (eg: California): " COMPANY_STATE
read -p "Enter Your or your company city (eg: San Francisco): " COMPANY_CITY
read -p "Enter Your or your company name (eg: MongoDB): " COMPANY_NAME
read -p "Enter Your or your company email address: " EMAIL_ADDRESS
read -p "do you have domain for these replica (yes/no): " DOMAIN
read -p "is this your first replica (yes/no): " FIRST_REPLICA
read -p "enter pass phrase for CA: " CA_PASSPHRASE
if [ "$DOMAIN" = "yes" ]; then
    read -p "Enter Your or your company domain (eg: example.com): " DOMAIN_NAME
    with_dns="DNS:$DOMAIN_NAME"
else
    DOMAIN_NAME=$(curl -s ipinfo.io/ip)
    with_dns="IP:$DOMAIN_NAME"
fi
if [ "$FIRST_REPLICA" = "no" ]; then
    read -p "Enter IP of first replica: " FIRST_REPLICA_IP
    read -p "Enter Password of first replica: " FIRST_REPLICA_PASSWORD
fi
# Update the system
echo "Updating the system..."
sudo apt-get update -y

# Create the new directory for MongoDB certificates
echo "Creating /etc/mongodb-certificates directory..."
sudo mkdir -p /etc/mongodb-certificates

# Set the ownership and permissions for the directory
echo "Setting permissions for /etc/mongodb-certificates..."
sudo chown mongodb:mongodb /etc/mongodb-certificates
sudo chmod 700 /etc/mongodb-certificates

# Create a Certificate Authority
echo "Creating a Certificate Authority..."
if [ "$FIRST_REPLICA" = "yes" ]; then
    echo "$CA_KEY_PASSPHRASE" | sudo openssl req -new -x509 -days 365 -keyout /etc/mongodb-certificates/mongodb.key -out /etc/mongodb-certificates/mongodb.crt \
    -subj "/C=$COUNTRY_CODE/ST=$COMPANY_STATE/L=$COMPANY_CITY/O=$COMPANY_NAME/emailAddress=$EMAIL_ADDRESS/CN=$DOMAIN_NAME" -passin stdin
    
    # Ensure the permissions are correct
    chmod 600 /etc/mongodb-certificates/mongodb.key
    chmod 600 /etc/mongodb-certificates/mongodb.crt
    sudo chown mongodb:mongodb /etc/mongodb-certificates/mongodb.key
    sudo chown mongodb:mongodb /etc/mongodb-certificates/mongodb.crt
else
    key_copied=false
    crt_copied=false
    
    while true; do
        if ! $key_copied; then
            echo "Copying key from the first replica..."
            if sshpass -p "$FIRST_REPLICA_PASSWORD" scp -o StrictHostKeyChecking=no root@"$FIRST_REPLICA_IP":/etc/mongodb-certificates/mongodb.key /etc/mongodb-certificates/mongodb.key; then
                echo "Key file copied successfully."
                key_copied=true
            else
                echo "Failed to copy key from the first replica."
            fi
        fi
        
        if ! $crt_copied; then
            echo "Copying certificate from the first replica..."
            if sshpass -p "$FIRST_REPLICA_PASSWORD" scp -o StrictHostKeyChecking=no root@"$FIRST_REPLICA_IP":/etc/mongodb-certificates/mongodb.crt /etc/mongodb-certificates/mongodb.crt; then
                echo "Certificate file copied successfully."
                crt_copied=true
            else
                echo "Failed to copy certificate from the first replica."
            fi
        fi
        
        if $key_copied && $crt_copied; then
            break
        else
            read -p "Leave empty to retry or enter 1 to exit: " user_choice
            if [[ "$user_choice" == "1" ]]; then
                read -p "Enter 1 to modify FIRST_REPLICA_PASSWORD or FIRST_REPLICA_IP, leave empty to exit: " modify_choice
                if [[ "$modify_choice" == "1" ]]; then
                    read -p "Enter new FIRST_REPLICA_IP (current: $FIRST_REPLICA_IP) or leave empty to keep current: " new_ip
                    if [[ ! -z "$new_ip" ]]; then
                        FIRST_REPLICA_IP="$new_ip"
                    fi
                    read -p "Enter new FIRST_REPLICA_PASSWORD (current: $FIRST_REPLICA_PASSWORD) or leave empty to keep current: " new_password
                    if [[ ! -z "$new_password" ]]; then
                        FIRST_REPLICA_PASSWORD="$new_password"
                    fi
                else
                    exit 1
                fi
            fi
        fi
    done
    # Ensure the permissions are correct
    chmod 600 /etc/mongodb-certificates/mongodb.key
    chmod 600 /etc/mongodb-certificates/mongodb.crt
    sudo chown mongodb:mongodb /etc/mongodb-certificates/mongodb.key
    sudo chown mongodb:mongodb /etc/mongodb-certificates/mongodb.crt
fi

# Create node-specific key and CSR
echo "Creating node-specific key"
sudo openssl genrsa -out /etc/mongodb-certificates/$DOMAIN_NAME.key 4096
# Ensure the permissions are correct
chmod 600 /etc/mongodb-certificates/$DOMAIN_NAME.key
sudo chown mongodb:mongodb /etc/mongodb-certificates/$DOMAIN_NAME.key

echo "Creating node-specific CSR"
openssl req -new -key /etc/mongodb-certificates/$DOMAIN_NAME.key -out /etc/mongodb-certificates/$DOMAIN_NAME.csr -subj "/C=$COUNTRY_CODE/ST=$COMPANY_STATE/L=$COMPANY_CITY/O=$COMPANY_NAME/emailAddress=$EMAIL_ADDRESS/CN=$DOMAIN_NAME" -reqexts SAN -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=$with_dns"))
# Ensure the permissions are correct
chmod 600 /etc/mongodb-certificates/$DOMAIN_NAME.csr
sudo chown mongodb:mongodb /etc/mongodb-certificates/$DOMAIN_NAME.csr

# Sign the CSR with your CA
echo "Signing the CSR with the CA..."
echo "$CA_KEY_PASSPHRASE" | sudo openssl x509 -req -in /etc/mongodb-certificates/$DOMAIN_NAME.csr -CA /etc/mongodb-certificates/mongodb.crt -CAkey /etc/mongodb-certificates/mongodb.key -CAcreateserial -out /etc/mongodb-certificates/$DOMAIN_NAME.crt -days 365 -extfile <(printf "subjectAltName=$with_dns") -passin stdin

# Create the .pem file
echo "Creating .pem file..."
sudo cat /etc/mongodb-certificates/$DOMAIN_NAME.key /etc/mongodb-certificates/$DOMAIN_NAME.crt > /etc/mongodb-certificates/$DOMAIN_NAME.pem
# Ensure the permissions are correct
chmod 600 /etc/mongodb-certificates/$DOMAIN_NAME.pem
sudo chown mongodb:mongodb /etc/mongodb-certificates/$DOMAIN_NAME.pem

# Update the MongoDB configuration file
echo "Updating the /etc/mongod.conf file with domain name $DOMAIN_NAME..."
sudo sed -i "/^net:/a \ \ tls:\n\ \ \ \ mode: requireTLS\n\ \ \ \ certificateKeyFile: /etc/mongodb-certificates/$DOMAIN_NAME.pem\n\ \ \ \ CAFile: /etc/mongodb-certificates/mongodb.crt" /etc/mongod.conf
sudo sed -i "/^net:/a \ \ maxIncomingConnections: 999999" /etc/mongod.conf
# Restart and check the status of MongoDB
echo "Restarting MongoDB and checking the status..."
sudo systemctl restart mongod
sleep 10
sudo systemctl status mongod --no-pager

echo "Script execution completed!"
