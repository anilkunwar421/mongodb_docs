
# #Step By Step Guide

### install mongoDB

```
wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -
```
The operation should respond with an OK message.

> OK

Next, create a list file for your MongoDB package under the /etc/apt/sources.list.d directory.

> echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list

Then, refresh the local package information index by issuing the following command.

> sudo apt update

With the package information database updated, execute the following command to install the latest stable version of the mongodb-org package

> sudo apt-get install -y mongodb-org

Once you've finished, the installation script creates a data directory in the following location.


> /var/lib/mongodb 

Also, MongoDB reports activity logs to a mongod.log file which you can locate from the location below.

> /var/log/mongodb

The MongoDB package runs under the service mongod. Use the following systemctl commands to manage it.

* Check the MongoDB status: ```sudo systemctl status mongod```
* Start the MongoDB service: ```sudo systemctl start mongod```
* Enable the MongoDB service to be started on boot: ```sudo systemctl enable mongod```
* Stop the MongoDB service: ```sudo systemctl stop mongod```
* Restart the MongoDB service. For instance after making configuration changes: ```sudo systemctl restart mongod```

You can tweak MongoDB settings by modifying the configuration file in the location below. For instance, you can define a different data or log directory.

> /etc/mongod.conf






