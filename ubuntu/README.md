# Let's getStarted
> First create 3 ubuntu server, 20.04 LTS recommanded and paste the bellow code on each server
```
curl -o initial_setup.sh https://raw.githubusercontent.com/anilkunwar421/mongodb_docs/main/ubuntu/initial_setup.sh && chmod +x initial_setup.sh &&
curl -o dns_setup.sh https://raw.githubusercontent.com/anilkunwar421/mongodb_docs/main/ubuntu/dns_setup.sh && chmod +x dns_setup.sh &&
curl -o enable_tls.sh https://raw.githubusercontent.com/anilkunwar421/mongodb_docs/main/ubuntu/enable_tls.sh && chmod +x enable_tls.sh
```
> Now run initial_setup.sh and dns_setup.sh on each server respectively, make sure you answer the asked questions properly
```
./initial_setup.sh
```
```
./dns_setup.sh
```
> Once mongodb is created, run the last file enable_tls.sh on each server
> Note : this step is only if you have domain assigned to replica set, if you are willing to proceed with ip, don't run this
```
./enable_tls.sh
```
### dns_setup.sh file maynot successfully initiate the replicaset, if this happended, follow this
```
mongosh -u mongo_db_admin -p yourPasswordHere --authenticationDatabase admin
```
```
use admin
```
```
rs.initiate(
   {
   _id: "replica_set_name",
   members: [
      { _id: 0, host: "replica1.example.com" },
      { _id: 1, host: "replica2.example.com" },
      { _id: 2, host: "replica3.example.com" }
   ]
})
```
