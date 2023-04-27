
# #Step By Step Guide

### install mongoDB

```
wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -
```
The operation should respond with an OK message.

> OK

Next, create a list file for your MongoDB package under the /etc/apt/sources.list.d directory.

```
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list
```
Then, refresh the local package information index by issuing the following command.
```
 sudo apt update
```
With the package information database updated, execute the following command to install the latest stable version of the mongodb-org package
```
 sudo apt-get install -y mongodb-org
```
Once you've finished, the installation script creates a data directory in the following location.


> /var/lib/mongodb 

Also, MongoDB reports activity logs to a mongod.log file which you can locate from the location below.

> /var/log/mongodb

The MongoDB package runs under the service mongod. Use the following systemctl commands to manage it.

* Check the MongoDB status:
 ```
 sudo systemctl status mongod
```
* Start the MongoDB service: 
```
sudo systemctl start mongod
```
* Enable the MongoDB service to be started on boot: 
```
sudo systemctl enable mongod
```
* Stop the MongoDB service: 
```
sudo systemctl stop mongod
```
* Restart the MongoDB service. For instance after making configuration changes: 
```
sudo systemctl restart mongod
```

You can tweak MongoDB settings by modifying the configuration file in the location below. For instance, you can define a different data or log directory.

> /etc/mongod.conf


### Configure Access Control on the MongoDB Server

By default, the MongoDB service is not secure. You must enable access control and restrict read/write access to the server. To do this, connect to the MongoDB server through the mongosh shell.
```
mongosh
```

Once you receive the `test >` prompt, switch to the `admin` database.
```
use admin
```
Then, execute the following command to create an administrative user with `superuser/root` privileges.
```
db.createUser(
      {
        user: "mongo_db_admin",

        pwd: passwordPrompt(),

        roles: [ { role: "userAdminAnyDatabase", db: "admin" }, "root"]
      }
      )
```
Enter your desired password and press `ENTER` to proceed. Then, exit from the MongoDB command-line interface by issuing the command below.

```
quit
```

Next, open the MongoDB configuration file using the nano text editor to enable authorization which is disabled by default.
```
sudo nano /etc/mongod.conf
```

Change the value of the #security: setting to the following option.
```
security:

  authorization: enabled
  keyFile: /etc/mongodb-keyfile
```

Save and close the file. Then, use this steps to generate `mongodb-keyfile`
```
touch /etc/mongodb-keyfile
chmod 600 /etc/mongodb-keyfile
openssl rand -base64 741 > /etc/mongodb-keyfile
sudo chown mongodb:mongodb /etc/mongodb-keyfile
sudo chown -R mongodb:mongodb /var/lib/mongodb
sudo chown -R mongodb:mongodb /var/log/mongodb
```

copy the mongodb-keyfile across all replica servers, make sure to replace `0.0.0.0` with server ip
```
scp /etc/mongodb-keyfile root@0.0.0.0:/etc/
```

now change permission of that file on those replica servers too
```
chmod 600 /etc/mongodb-keyfile
sudo chown mongodb:mongodb /etc/mongodb-keyfile
sudo chown -R mongodb:mongodb /var/lib/mongodb
sudo chown -R mongodb:mongodb /var/log/mongodb
```

restart the MongoDB server to effect the new configuration changes.
```
sudo systemctl restart mongod
```
connect to your MongoDB instance by establishing a new `mongosh` session by executing the following command. The `mongo_db_admin` is the `superuser/root` account that you created earlier.
```
mongosh -u mongo_db_admin -p yourPasswordHere --authenticationDatabase admin
```

Create a new e_commerce database. Please note MongoDB does not support the CREATE DATABASE command. Instead, to set up a new database, simply switch the context to an empty database by executing the use command. To create the e_commerce database, run the following command.
```
use e_commerce
```

> Till here, the basic mongoDB database is created and ready to run! to create multiple replica sets and secure it using TLS, follow these instructions!


### Configuring DNS Resolution

```
sudo nano /etc/hosts
```

you can edit this file in this format :
```
. . .
127.0.0.1 localhost

203.0.113.0 mongo0.replset.member
203.0.113.1 mongo1.replset.member
203.0.113.2 mongo2.replset.member
. . .
```
Updating Each Server’s Firewall Configurations with UFW
```
sudo ufw allow from mongo1_server_ip to any port 27017
sudo ufw allow from mongo2_server_ip to any port 27017
sudo ufw allow from mongo3_server_ip to any port 27017
```

Enabling Replication in Each Server’s MongoDB Configuration File
```
sudo nano /etc/mongod.conf
```

find `bindIp` And ``#replication`` and update like this on Each Server, make sure you change corresponding dns name like `mongo0.replset.member`, `mongo1.replset.member`, `mongo2.replset.member`
```
. . .
# network interfaces
net:
  port: 27017
  bindIp: 127.0.0.1,mongo0.replset.member
  
replication:
  replSetName: "this_name_should_be_same_on_all_server"
. . . 
```

Now restart the mongodb server
```
sudo systemctl restart mongod
```

Starting the Replica Set and Adding Members
On mongo0, open up the MongoDB shell:
```
mongosh -u mongo_db_admin -p yourPasswordHere --authenticationDatabase admin
```
```
use admin
```
now initiate replicaset like this 
```
rs.initiate(
   {
   _id: "rs0",
   members: [
      { _id: 0, host: "mongo0.replset.member" },
      { _id: 1, host: "mongo1.replset.member" },
      { _id: 2, host: "mongo2.replset.member" }
   ]
})
```
Be aware that if you have additional nodes that you’d like to add to the replica set in the future, you can do so with the rs.add() method after configuring them as you did the current replica set members in the previous steps:
```
rs.add( "mongo3.replset.member" )
```

In order to connect mongoDB from your local machine, make sure you add firewall rules in each server, replace `0.0.0.0` with your ip
```
sudo ufw allow from 0.0.0.0 to any port 27017
```
> Note: we completed the replica set setup and it should work fine with no issues, you can follow the bellow mentioned steps if you want to enable TLS too!

### Enable TLS
Update your system:
First, make sure your Ubuntu server is up-to-date by running the following commands:
```
sudo apt-get update
sudo apt-get upgrade
```
create a new folder `/etc/mongodb-certificates` on all replica servers
```
mkdir /etc/mongodb-certificates
```
Give these permissions to folder `/etc/mongodb-certificates`
```
chown mongodb:mongodb /etc/mongodb-certificates
chmod 700 /etc/mongodb-certificates
```
Create a Certificate Authority (CA):
```
openssl req -newkey rsa:4096 -nodes -keyout mongodb.key -x509 -days 365 -out mongodb.crt
```
copy the mongodb.key and mongodb.crt file across all replica servers, replace `0.0.0.0` with your server ip
```
scp /etc/mongodb-certificates/mongodb.key root@0.0.0.0:/etc/mongodb-certificates/
```

now on each server create .pem file like this :
```
openssl genrsa -out node1.key 4096
```
```
openssl req -new -key node1.key -out node1.csr -subj
```
```
"/C=COUNTRY_CODE/ST=COMPANY_STATE/L=COMPANY_CITY/O=COMPANY_NAME/emailAddress=business@example.com/CN=node1.example.com" -reqexts SAN -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS:node1.example.com"))
```
```
openssl x509 -req -in node1.csr -CA mongodb.crt -CAkey mongodb.key -CAcreateserial -out node1.crt -days 365 -extfile <(printf "subjectAltName=DNS:node1.example.com")
```
