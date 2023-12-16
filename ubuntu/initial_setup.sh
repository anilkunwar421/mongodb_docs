#!/bin/bash

# Prompt user for input
read -p "Enter MongoDB version to install (e.g., 7.0): " mongodb_version
read -p "Is this your first replicaSet (yes/no): " first_replica
read -p "Enter MongoDb admin user password (use the same on all replica set, username is mongo_admin): " replica_pw
if [ "$first_replica" != "yes" ]; then
  read -p "Enter the first replica set member's IP address: " first_replica_ip
  read -p "Enter the first replica set member's server SSH password: " first_replica_pw
  echo ""  # Move to a new line after the password input
fi

# Add MongoDB GPG key
wget -qO - https://www.mongodb.org/static/pgp/server-${mongodb_version}.asc | sudo apt-key add -

# Create MongoDB list file
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/${mongodb_version} multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-${mongodb_version}.list

# Update local package index
sudo apt-get update

# Install MongoDB package
sudo apt-get install -y mongodb-org

# Install SSH Pass
sudo apt-get install -y sshpass

# Starting and enabling MongoDB service
sudo systemctl start mongod
sudo systemctl enable mongod
sudo systemctl stop mongod
sudo systemctl start mongod
# Wait for MongoDB to restart
sudo sleep 10
#Connect to MongoDB without access control.
mongosh --port 27017 <<EOF
use admin
db.createUser({
  user: "mongo_admin",
  pwd: "$replica_pw",
  roles: [ { role: "root", db: "admin" } ]
})
EOF
#create a keyfile for authentication
if [ "$first_replica" != "yes" ]; then
  # Use sshpass with scp to copy the keyfile from the first replica set member
  sudo sshpass -p "$first_replica_pw" scp -o StrictHostKeyChecking=no root@"$first_replica_ip":/etc/mongodb-keyfile /etc/mongodb-keyfile
  
  # Ensure the permissions are correct
  sudo chmod 600 /etc/mongodb-keyfile
  sudo chown mongodb:mongodb /etc/mongodb-keyfile
  sudo chown -R mongodb:mongodb /var/lib/mongodb
  sudo chown -R mongodb:mongodb /var/log/mongodb
  else
  # If this is the first replica set member, create the keyfile
  sudo touch /etc/mongodb-keyfile
  sudo chmod 600 /etc/mongodb-keyfile
  sudo openssl rand -base64 741 > /etc/mongodb-keyfile
  sudo chown mongodb:mongodb /etc/mongodb-keyfile
  sudo chown -R mongodb:mongodb /var/lib/mongodb
  sudo chown -R mongodb:mongodb /var/log/mongodb
fi

# Step 4: Enable access control.
# This involves uncommenting the 'security' section and setting 'authorization' to 'enabled'.
sudo sed -i '/^#security:/s/^#//' /etc/mongod.conf
sudo sed -i '/^security:/a \  keyFile: /etc/mongodb-keyfile' /etc/mongod.conf
sudo sed -i '/^security:/a \  authorization: enabled' /etc/mongod.conf

# Step 5: Restart MongoDB to apply the changes.
sudo systemctl restart mongod


echo "MongoDB installation initial step complete."
