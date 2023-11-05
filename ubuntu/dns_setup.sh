#!/bin/bash

# Prompt user for input
read -p "Name of replica set (e.g., company_replicaset): " name
read -p "Replica 1 IP: " replica1_ip
read -p "Replica 2 IP: " replica2_ip
read -p "Replica 3 IP: " replica3_ip
read -p "Is this the last replica you are updating? (Yes/No): " last_replica
read -p "Current replica domain (optional): " replica_identifier

# Check if replica_identifier is empty and ask for IP
if [ -z "$replica_identifier" ]; then
    read -p "Current replica IP: " replica_identifier
fi

if [ "$last_replica" = "Yes" ]; then
    read -p "Enter mongodb admin password: " ADMIN_PWD
    read -p "Enter 1st replica domain (optional): " first_replica_domain
    read -p "Enter 2nd replica domain (optional): " second_replica_domain
    read -p "Enter 3rd replica domain (optional): " third_replica_domain
fi

# Update UFW rules
echo "y" | sudo ufw enable
sudo ufw allow 22
sudo ufw allow from $replica1_ip to any port 27017
sudo ufw allow from $replica2_ip to any port 27017
sudo ufw allow from $replica3_ip to any port 27017
sudo ufw reload

# Update bindIp with the current replica identifier
sudo sed -i "/  bindIp:/s/127.0.0.1/&,$replica_identifier/" /etc/mongod.conf

# Uncomment and set the replica set name
sudo sed -i "s/#replication:/replication:/" /etc/mongod.conf
sudo sed -i '/^replication:/a \ \ replSetName: '"$name"'' /etc/mongod.conf

# Restart MongoDB to apply changes
sudo systemctl restart mongod

# If this is the last replica, configure replica set
if [ "$last_replica" = "Yes" ]; then
    # Wait for MongoDB to restart
    sleep 10
    
    # Check if MongoDB is ready
    until echo 'db.runCommand({ ping: 1 })' | mongosh --port 27017 -u "mongo_admin" -p "$ADMIN_PWD" --authenticationDatabase admin --quiet; do
        sleep 5
    done
    
    # Execute the replica set initiation
    output=$(echo "rs.initiate({
        _id: '$name',
        members: [
            { _id: 0, host: '$first_member' },
            { _id: 1, host: '$second_member' },
            { _id: 2, host: '$third_member' }
        ]
    });" | mongosh --port 27017 -u "mongo_admin" -p "$ADMIN_PWD" --authenticationDatabase admin --quiet 2>&1)
    
    # Check the output for success or failure
    if echo "$output" | grep -q '"ok" : 1'; then
        echo "Replica set configured successfully."
    else
        echo "Failed to configure replica set:"
        echo "$output"
    fi
fi


