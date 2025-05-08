# DockerPgHA  
  
The following is for dockerizing a simulated multi data center Postgres 16 on Ubuntu 20.04 using Patroni, etcd, pgbackrest and Docker.  
  
You have the ability to generate docker-compose files for x number of data centers and x number of nodes per data center.  
  
Below is a TL;DR section followed by a more detailed explanation of what is happening.  


## New changes made as noted here.

### Naming changes
First of all lets start with naming of service / containers

Since this is intended to mimic multi data center environments everything is named in a way that makes identification easy.

For example when you run genCompose to generate the docker-compose file as listed below, you will specify a name for your pg servers. In this example we will call it **demo**

If you decide to mimic 2 data centers with 3 nodes per data center, this is what to expect for naming:

**pgha-demo1-1-1**

**[prefix]-[node name and node number]-[datacenter]-[docker instance]**

- Where prefix will be pgha to identify easily i with docker ps . etc ...
- The node name with a number representing which node number out of the nodes per data center 
- The data center number the node will reside in
- The docker instance the deploy is running under. ( you could have multiple docker instance running with the same name so the instance, makes it unique

So in the above example, **pgha-demo1-1-1** can quickly be identified as the first demo **demo1** of  3 nodes inside data center 1. Where as **pgha-demo3-2-1** would be identified as the 3rd demo node inside data center 2


### Networking

We now create x number of networks based on the number of data centers. Plus a non data center network. For example, if you create 2 data centers,  You will generate a total of 3 networks.  1 network for each data center and 1 non data center network,
```
pgha-net1-1
pgha-net2-1  
pgha-net3-1
```
In this case the naming is **[prefix]-[net data center]-[container number]**

### Etcd distribution

Based on the number of data centers we mimic, in order to maintain a quorum we now have x number of etcd hosts **per data center** tied to a network, plus **one extra etcd host outside of a data center network**.  This is the one that will help keep a quorum if a dc goes down.

### pgbackrest 

Pgbackrest server gets placed on the non data center network

### Optionally run the haproxy instance

Download the pgTraining  repo from here:

https://github.com/jtorral/pgTraining

Follow the instructions to build the image and run the container.

Use the following to get the basic container running

```
929 docker run -p 5411:5432 -p 5000:5000 -p 5001:5001 --env=PGPASSWORD=postgres -v pg1-pgdata:/pgdata --hostname haProxy --network=dockerpgha_pgha-net1-1 --name=haProxy -dt pg16-rocky8-bundle
```

Notice, we are attaching to the network defined for our PgHa environment.

After you get it running, connect the additional networks to the container so it is visible to the other servers and vice versa.

```
docker network connect dockerpgha_pgha-net2-1 haProxy  
docker network connect dockerpgha_pgha-net3-1 haProxy
```

Now get the config file set up in ```/etc/haproxy/haproxy.cfg```

The file is can be copied from this repo as well.

```haproxy.cfg.sample```


If all goes as planned, start haproxy manually  

```haproxy -V -f /etc/haproxy/haproxy.cfg```

You can run it in the background. The above is for testing

Now you can connect to a primary database via haproxy like so

```psql -h localhost -p 5000 -U postgres```

To connect to read only, use port 5001

### Added basic script for status

This was a lte night though so it needs to be improved. However, its a good start to getting info about containers.

pghaStat

produces output like this

```
Please wait while we gather some data ...  
  
Instance used to query env : pgha-demo1-1-1  
Patroni Leader : pgha-demo1-2-1  
Active Patroni nodes : 6  
DC hosting Patroni Leader : 2  
Docker containers in DC : pgha-demo2-2-1 pgha-demo1-2-1 pgha-demo3-2-1 pgha-etcd4-2-1 pgha-etcd3-2-1  
  
  
Patroni cluster details ....  
  
  
+ Cluster: pgha_cluster (7501823498374451243) ----------+----+-----------+  
| Member | Host | Role | State | TL | Lag in MB |  
+----------------+----------------+---------+-----------+----+-----------+  
| pgha-demo1-1-1 | pgha-demo1-1-1 | Replica | streaming | 7 | 0 |  
| pgha-demo1-2-1 | pgha-demo1-2-1 | Leader | running | 7 | |  
| pgha-demo2-1-1 | pgha-demo2-1-1 | Replica | streaming | 7 | 0 |  
| pgha-demo2-2-1 | pgha-demo2-2-1 | Replica | streaming | 7 | 0 |  
| pgha-demo3-1-1 | pgha-demo3-1-1 | Replica | streaming | 7 | 0 |  
| pgha-demo3-2-1 | pgha-demo3-2-1 | Replica | streaming | 7 | 0 |  
+----------------+----------------+---------+-----------+----+-----------+  
  
ETCD cluster details ....  
  
  
+---------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+  
| ENDPOINT | ID | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |  
+---------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+  
| pgha-etcd2-1-1:2379 | 856afccebea5e496 | 3.5.13 | 127 kB | false | false | 3 | 344 | 344 | |  
| pgha-etcd4-2-1:2379 | 4b1ef8498608d2d9 | 3.5.13 | 127 kB | false | false | 3 | 344 | 344 | |  
| pgha-etcd5-3-1:2379 | 84ca01859d3aca7d | 3.5.13 | 127 kB | false | false | 3 | 344 | 344 | |  
| pgha-etcd3-2-1:2379 | efa6a64b5fec8ce | 3.5.13 | 127 kB | true | false | 3 | 344 | 344 | |  
| pgha-etcd1-1-1:2379 | d8637f2e8aa15c2e | 3.5.13 | 127 kB | false | false | 3 | 344 | 344 | |  
+---------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```


  
## TL;DR;  
  
  
**At a minimum, use docker-compose version 1.29.2. Using an older version may generate errors when you try to run the docker-compose.yaml file**  
  
  
From inside the etcd folder ...  
  
```  
docker build -t pgha-etcd-3.5 .  
```  
  
From inside the pgpatroni folder ...  
  
```  
docker build -t pgha-pg16-patroni .  
```  
  
From inside the pgbackrest folder ...  
  
```  
docker build -t pgha-pgbackrest .  
```  
  
From the main folder  
  
We will generate containers for 2 data centers with 2 nodes each using the docker-compose file generator  
  
```  
./genCompose -n pg -d 2 -c 2 -v16  
```  
  
```  
Usage:  
./genCompose [OPTION]  
  
-d Number of data centers to simulate. (default = 1)  
-c number of nodes per data center. (default = 2)  
-n Prefix name to use for db connertainer.  
-v Postgres Major version number. i.e 16  
-b Start patroni in background and keep container running even if it stops.  
Good for upgrades and maintenance tasks.  
  
Number of db nodes is capped at 9. So (-d * -c) should be <= 9  
Number of etcd nodes are calculated on (-d * -c ) / 2 + 1  
```  
  
From the main folder  
  
```  
docker-compose create  
```  
  
Followed by  
  
```  
docker-compose start  
```  
  
You should now be able to access the containers  
  
## The details ....  
  
What we have installed ...  
  
```  
DISTRIB_ID=Ubuntu  
DISTRIB_RELEASE=22.04  
DISTRIB_CODENAME=jammy  
DISTRIB_DESCRIPTION="Ubuntu 22.04.4 LTS"  
PRETTY_NAME="Ubuntu 22.04.4 LTS"  
NAME="Ubuntu"  
VERSION_ID="22.04"  
VERSION="22.04.4 LTS (Jammy Jellyfish)"  
VERSION_CODENAME=jammy  
ID=ubuntu  
ID_LIKE=debian  
HOME_URL="https://www.ubuntu.com/"  
SUPPORT_URL="https://help.ubuntu.com/"  
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"  
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"  
UBUNTU_CODENAME=jammy  
```  
  
```  
patronictl version 3.3.0  
```  
  
```  
pgBackRest 2.51  
```  
  
```  
etcd Version: 3.5.13  
Git SHA: c9063a0dc  
Go Version: go1.21.8  
Go OS/Arch: linux/amd64  
```  
in addition to the building block packages above, the following are also installed. Feel free to modify the Docker file and remove packages you don't feel you need for a lighter footprint.  
  
```  
&& apt-get install -y wget \  
&& apt-get install -y curl \  
&& apt-get install -y jq \  
&& apt-get install -y vim \  
&& apt-get install -y apt-utils \  
&& apt-get install -y net-tools \  
&& apt-get install -y iputils-ping \  
&& apt-get install -y gnupg \  
&& apt-get install -y openssh-server \  
&& apt-get install -y less \  
&& apt-get install -y python3 \  
&& apt-get install -y python3-etcd \  
&& apt-get install -y postgresql-common  
```  
  
  
### Why SSH in our containers?  
In order for pgbackrest to work and interact with the nodes on the network we need sshd running. We need to be trusted across all the servers.  
Prior to building your images, generate an ssh key that you will copy into all the containers. Or, you can use the ones in this repo which reside in the main folder. They include the public, private and authorised_keys.  
  
**The ssh keys in this repo were generated inside a docker container and have no existence outside of them and have since been trashed. Feel free to use them.**  
  
sshd is started at the command line  
```  
/usr/sbin/sshd  
```  
rather than running under systemd.  
  
### Docker images  
  
The generated images listed below are what we will use.  
  
```  
docker images  
  
REPOSITORY TAG IMAGE ID CREATED SIZE  
pgha-pg16-patroni latest bf7e8fa50dc4 2 hours ago 548MB  
pgha-pgbackrest latest 23765655a0d5 2 hours ago 314MB  
pgha-etcd-3.5 latest edab3b23c2c4 3 hours ago 344MB  
```  
  
### genCompose  
  
The genCompose file lets you generate docker-compose.yaml files for your desired environment.  
  
1. etcd containers are created based on your choice below  
2. Specify the number of data centers to simulate (-d). Docker nertwork is assignbed based on dc number..  
3. specify the number of postgres containers per data center (-c). Default is 2.  
4. name your postgres containers.  
5. Specify the version of postgres. Used vor data directory. ( Will automate this eventually )  
6. Specify if the patroini containers will run in background and keep container up even if patroni is down.  
  
When you run genCompose and specify -b, patroni will start with a nohup followed by a  
```  
tail -f /dev/null  
```  
This will allow you to make changes in patroni that require it to stop and restart manually by not stopping the container when the patroni process terminates.  
  
It is also used for custom backup restores.  
  
When naming a postgres container, it really means a prefix for the container name because genCompose will generate the name with a specific format.  
  
For example, If you were to specify the name **pg** and 2 data centers with 2 nodes per data center, genCompose would create the following nodes.  
  
1. pg1-node1  
2. pg1-node2  
3. pg2-node1  
4. pg2-node2  
  
You create a node name of "dude" you would get  
  
dude1-node1, dude1-node2 and so on ...  
  
the number after the name prefix is synonymous with a data center. So, pg1 would reside in data center 1.  
  
genCompose builds 3 networks within the docker environment.  
  
1. net1  
2. net2  
3. net3  
  
As each node gets added to the docker-compose file, priority is given to the network based on the node name.  
  
1. pg1 nodes would be prioritized to net1  
2. pg2 nodes would be prioritized to net2  
3. pg3 nodes would be prioritized to net3  
  
Additional data centers woud loop around net1 through 3.  
Feel free to modify the genCompose script and add additional networks and change the priority logic.  
  
The script adds **depends_on** sections to the postgres and pgbackrest service.  
Postgres depends on etcd services to be running prior to starting.  
Postgres, (except for first node in first dc) depends on pg1 postgres to be running as well.  
  
  
Keep in mind, depends_on is not the best way to specify startup order. Health checks should be used.  
  
Additionally, genCompose assigns static port mapping to postgres containers so you can consistently access them with the same connection string.  
genCompose trys to identify the highest port number already mapped to 5432 in your environment and create maps higher than that.  
  
### The running environment  
  
In this example, there is one data center with 9 nodes  
  
```  
CONTAINER ID IMAGE COMMAND CREATED STATUS PORTS NAMES  
c83187335a3d 3bef0a1c14a4 "/entrypoint.sh" About an hour ago Up About an hour 0.0.0.0:50558->5432/tcp pgha-pg1-node8  
e6ab34c49d96 3bef0a1c14a4 "/entrypoint.sh" About an hour ago Up About an hour 0.0.0.0:50559->5432/tcp pgha-pg1-node9  
da696d20bde7 3bef0a1c14a4 "/entrypoint.sh" About an hour ago Up About an hour 0.0.0.0:50553->5432/tcp pgha-pg1-node3  
d055362db7aa 3bef0a1c14a4 "/entrypoint.sh" About an hour ago Up About an hour 0.0.0.0:50552->5432/tcp pgha-pg1-node2  
968ceb990f4f 3bef0a1c14a4 "/entrypoint.sh" About an hour ago Up About an hour 0.0.0.0:50556->5432/tcp pgha-pg1-node6  
dc7fc7aa2519 pgha-pgbackrest "/entrypoint.sh" About an hour ago Up About an hour pgha-pgbackrest  
a1f85f977850 3bef0a1c14a4 "/entrypoint.sh" About an hour ago Up About an hour 0.0.0.0:50554->5432/tcp pgha-pg1-node4  
e80e26167b0c 3bef0a1c14a4 "/entrypoint.sh" About an hour ago Up About an hour 0.0.0.0:50557->5432/tcp pgha-pg1-node7  
8596dfc62104 3bef0a1c14a4 "/entrypoint.sh" About an hour ago Up About an hour 0.0.0.0:50555->5432/tcp pgha-pg1-node5  
b80a73f9bb4a 3bef0a1c14a4 "/entrypoint.sh" About an hour ago Up About an hour 0.0.0.0:50551->5432/tcp pgha-pg1-node1  
9728a711dee1 pgha-etcd-3.5 "/usr/bin/etcd --nam…" About an hour ago Up About an hour 2380/tcp, 0.0.0.0:52635->2379/tcp pgha-etcd3  
1a33819a0c11 pgha-etcd-3.5 "/usr/bin/etcd --nam…" About an hour ago Up About an hour 2380/tcp, 0.0.0.0:52637->2379/tcp pgha-etcd1  
db8dcedb06a6 pgha-etcd-3.5 "/usr/bin/etcd --nam…" About an hour ago Up About an hour 2380/tcp, 0.0.0.0:52634->2379/tcp pgha-etcd2  
afb30ebb7d4b pgha-etcd-3.5 "/usr/bin/etcd --nam…" About an hour ago Up About an hour 2380/tcp, 0.0.0.0:52638->2379/tcp pgha-etcd4  
58f7baa8c01c pgha-etcd-3.5 "/usr/bin/etcd --nam…" About an hour ago Up About an hour 2380/tcp, 0.0.0.0:52636->2379/tcp pgha-etcd5  
```  
  
  
### entrypoint scripts  
  
Some notes about the entrypoint scripts.  
  
#### pgpatroni entrypoint details  
  
This script will  
1. create patroni.conf  
2. create pgbackrest.conf  
3. Check if it has to restore itself from backup  
4. Remove strict host key checking from ssh config so no answering prompts is required  
  
If the file /pgha/config/restoreme exists, the container will try to initialize itself from a restored backup. Additional action is required and detailed below.  
  
#### pgbackrest entrypoint details  
  
This script will  
1. create pgbackrest.conf  
2. Check for the presence of a required stanza and attempt to create it.  
  
If the stanza does not exist, pgbackrest will attempt to create it 10 times with a 15 second sleep between each attempt.  
  
You could manually create it with the following command. **Remember all pgbackrest commands must be run as user postgres.**  
  
```  
docker exec -it pgha-pgbackrest sudo -u postgres pgbackrest --stanza=${STANZA_NAME} stanza-create  
```  
  
  
### Backup and restores  
  
  
  
There are two ways of restoring backups for these docker containers.  
  
First things first. Make sure you have backups.  
  
  
##### Method 1  
  
Simply create the trigger file /pgha/config/restoreme by running  
```  
/pgha/config/restoremeOnStartup  
```  
and following the process instructions generated by the restoremeOnStartup script. This will restore from the latest backup in your repo.  
  
Here is a sample output from the command  
  
```  
************* READ THIS *****************  
  
Copy these commands and shut down the replica containers before restarting pgha-pg1-node1  
  
docker stop pgha-pg1-node2  
docker stop pgha-pg1-node3  
  
Validate all replicas are down and pg1-node1 is running as the Leader  
  
patronictl -c /pgha/config/patroni.conf list  
  
Before restarting pgha-pg1-node1.  
  
docker restart pgha-pg1-node1  
  
When pg1-node1 is back on line and running as a Leader again, restart the replicas.  
  
docker exec -it pgha-pg1-node1 patronictl -c /pgha/config/patroni.conf list  
  
Restart the replicas  
  
docker start pgha-pg1-node2  
docker start pgha-pg1-node3  
  
If there are error and the replica does not come online, you can reinitilaze them with the following commands.  
  
- Note:  
- Depending on the size of the database, this could take time.  
- Consider logging into the conatiner and checking the logs before reinitilizing.  
- You must run these from inside one of the containers  
  
curl -s http://pg1-node2:8008/reinitialize -XPOST -d '{"force":"true"}'  
curl -s http://pg1-node3:8008/reinitialize -XPOST -d '{"force":"true"}'  
  
Or you can use the patronictl commands below.  
  
patronictl -c /pgha/config/patroni.conf reinit pgha_cluster pg1-node2 --force  
patronictl -c /pgha/config/patroni.conf reinit pgha_cluster pg1-node3 --force  
  
If you change your mind, remove the trigger file /pgha/config/restoreme *****  
```  
  
##### Method 2  
  
The other way to restore is using custom pgbackrest restore commands. This requires that the container stays running even if patroni is shut down. You can accomplish this by passing passing the option **-b** when you generate you  
r docker-compose file using genCompose.  
  
  
  
The **-b** will create the compose-file and indicate that when patroni starts, it is done so using nohup and then followed by a  
```  
tail -f /dev/null  
```  
which keeps the container up even when patroni is not running.  
  
  
##### A high level overview of the process is as follows:  
  
  
  
- make sure docker-compose was generated with -b option  
- as root inside the Leader node validate you have backups with the following command:  
- ```sudo -u postgres pgbackrest --config=${CFG_DIR}/pgbackrest.conf --stanza=${STANZA_NAME} info ```  
- Bring down all replica containers  
- ```docker stop pgha-pg1-node2```  
- ```docker stop pgha-pg1-node3```  
- Validate the primary is the only service running  
- ```patronictl -c /pgha/config/patroni.conf list```  
  
```  
+ Cluster: pgha_cluster (7366718977191354411) --+-----------+  
| Member | Host | Role | State | TL | Lag in MB |  
+-----------+-----------+--------+---------+----+-----------+  
| pg1-node1 | pg1-node1 | Leader | running | 1 | |  
+-----------+-----------+--------+---------+----+-----------+  
```  
  
  
- log into the primary container  
- look for the patroni process  
- ```root@pg1-node1:/# ps -ef | grep patroni ```  
  
```  
root 13 1 0 19:51 ? 00:00:00 sudo -u postgres nohup /usr/bin/patroni /pgha/config/patroni.conf  
postgres 15 13 0 19:51 ? 00:00:00 /usr/bin/python3 /usr/bin/patroni /pgha/config/patroni.conf  
root 331 96 0 20:04 pts/0 00:00:00 grep --color=auto patroni  
```  
  
- kill the pid running the sudo command  
- ```kill 13```  
- Make sure patroni is not running anymore with another ps command  
- Empty out the data directory  
- ```rm -rf /pgdata/16/*```  
- Run you custom pgbackrest restore command:  
- For this example, We are just restoring the latest backup. However, you can get specific with sets, times, db's etc ..  
- ```sudo -u postgres pgbackrest --config=${CFG_DIR}/pgbackrest.conf --log-path=${CFG_DIR} --stanza=${STANZA_NAME} --pg1-path=${DATADIR} --log-level-console=info --log-level-file=detail restore ```  
- Sample output  
```  
sudo -u postgres pgbackrest --config=/pgha/config/pgbackrest.conf --log-path=/pgha/config --stanza=pgha_db --pg1-path=/pgdata/16 --log-level-console=info --log-level-file=detail restore  
root@pg1-node1:/pgdata/16# sudo -u postgres pgbackrest --config=${CFG_DIR}/pgbackrest.conf --log-path=${CFG_DIR} --stanza=${STANZA_NAME} --pg1-path=${DATADIR} --log-level-console=info --log-level-file=detail restore  
2024-05-08 20:07:36.398 P00 INFO: restore command begin 2.51: --config=/pgha/config/pgbackrest.conf --exec-id=347-3f5dbef2 --log-level-console=info --log-level-file=detail --log-path=/pgha/config --pg1-path=/pgdata/16 --process-m  
ax=16 --repo1-host=pgbackrest --repo1-host-user=postgres --stanza=pgha_db  
2024-05-08 20:07:36.652 P00 INFO: repo1: restore backup set 20240508-195548F, recovery will start at 2024-05-08 19:55:48  
2024-05-08 20:07:52.204 P00 INFO: write updated /pgdata/16/postgresql.auto.conf  
2024-05-08 20:07:52.257 P00 INFO: restore global/pg_control (performed last to ensure aborted restores cannot be started)  
2024-05-08 20:07:52.259 P00 INFO: restore size = 202.4MB, file total = 1274  
2024-05-08 20:07:52.259 P00 INFO: restore command end: completed successfully (15862ms)  
```  
  
- For fresh logs, remove the log files from the log directory  
- ```rm /pgdata/16/log/*```  
- Restart the container  
- Validate the node is running as a Leader  
- ```docker exec -it pgha-pg1-node1 patronictl -c /pgha/config/patroni.conf list```  
  
```  
+ Cluster: pgha_cluster (7366718977191354411) --+-----------+  
| Member | Host | Role | State | TL | Lag in MB |  
+-----------+-----------+--------+---------+----+-----------+  
| pg1-node1 | pg1-node1 | Leader | running | 2 | |  
+-----------+-----------+--------+---------+----+-----------+  
```  
  
- If yes,  
- Restart the replicas  
- ```docker restart pgha-pg1-node2```  
- Validate it comes up and resyncs  
  
**Depending on your db size and backup, this could take some time.**  
  
- ```docker exec -it pgha-pg1-node1 patronictl -c /pgha/config/patroni.conf list```  
  
```  
+ Cluster: pgha_cluster (7366718977191354411) +----+-----------+  
| Member | Host | Role | State | TL | Lag in MB |  
+-----------+-----------+---------+-----------+----+-----------+  
| pg1-node1 | pg1-node1 | Leader | running | 2 | |  
| pg1-node2 | pg1-node2 | Replica | streaming | 2 | 0 |  
+-----------+-----------+---------+-----------+----+-----------+  
```  
  
- Repeat replica restarts for remaining replicas  
- ```docker restart pgha-pg1-node3 ```  
- ```docker exec -it pgha-pg1-node1 patronictl -c /pgha/config/patroni.conf list```  
- **Be patient**  
```  
+ Cluster: pgha_cluster (7366718977191354411) +----+-----------+  
| Member | Host | Role | State | TL | Lag in MB |  
+-----------+-----------+---------+-----------+----+-----------+  
| pg1-node1 | pg1-node1 | Leader | running | 2 | |  
| pg1-node2 | pg1-node2 | Replica | streaming | 2 | 0 |  
| pg1-node3 | pg1-node3 | Replica | stopped | | unknown |  
+-----------+-----------+---------+-----------+----+-----------+  
```  
- ```docker exec -it pgha-pg1-node1 patronictl -c /pgha/config/patroni.conf list```  
  
```  
+ Cluster: pgha_cluster (7366718977191354411) +----+-----------+  
| Member | Host | Role | State | TL | Lag in MB |  
+-----------+-----------+---------+-----------+----+-----------+  
| pg1-node1 | pg1-node1 | Leader | running | 2 | |  
| pg1-node2 | pg1-node2 | Replica | streaming | 2 | 0 |  
| pg1-node3 | pg1-node3 | Replica | streaming | 2 | 0 |  
+-----------+-----------+---------+-----------+----+-----------+  
```  
  
  
  
  
  
#### Want to perform a backup ?  
  
```  
docker exec -it pgha-pgbackrest sudo -u postgres pgbackrest --stanza=${STANZA_NAME} --type=full backup  
```  
  
```  
.  
.  
.  
2024-05-04 01:32:39.073 P00 INFO: check archive for segment(s) 000000050000000000000013:000000050000000000000013  
2024-05-04 01:32:39.283 P00 INFO: new backup label = 20240504-013221F  
2024-05-04 01:32:39.320 P00 INFO: full backup size = 29.5MB, file total = 1275  
2024-05-04 01:32:39.320 P00 INFO: backup command end: completed successfully (24286ms)  
2024-05-04 01:32:39.320 P00 INFO: expire command begin 2.51: --exec-id=3240-c9b97e1e --log-level-console=detail --log-level-file=detail --repo1-path=/pgha/pgbackrest --repo1-retention-archive-type=full --repo1-retention-full=2  
--stanza=pgha_db  
2024-05-04 01:32:39.326 P00 DETAIL: repo1: 16-1 archive retention on backup 20240503-231613F, start = 000000010000000000000006  
2024-05-04 01:32:39.329 P00 INFO: repo1: 16-1 remove archive, start = 000000010000000000000001, stop = 000000010000000000000005  
2024-05-04 01:32:40.131 P00 INFO: expire command end: completed successfully (811ms)  
```  
  
#### Want to check your backup repo?  
  
```  
docker exec -it pgha-pgbackrest sudo -u postgres pgbackrest --stanza=${STANZA_NAME} info  
```  
  
```  
stanza: pgha_db  
status: ok  
cipher: none  
  
db (current)  
wal archive min/max (16): 000000010000000000000006/000000050000000000000013  
  
full backup: 20240503-231613F  
timestamp start/stop: 2024-05-03 23:16:13+00 / 2024-05-03 23:16:18+00  
wal start/stop: 000000010000000000000006 / 000000010000000000000006  
database size: 29.4MB, database backup size: 29.4MB  
repo1: backup set size: 3.9MB, backup size: 3.9MB  
  
full backup: 20240504-013221F  
timestamp start/stop: 2024-05-04 01:32:21+00 / 2024-05-04 01:32:38+00  
wal start/stop: 000000050000000000000013 / 000000050000000000000013  
database size: 29.5MB, database backup size: 29.5MB  
repo1: backup set size: 3.9MB, backup size: 3.9MB  
```  
  
  
  
### Patroni basics  
  
The patroni config file is in /pgha/config/patroni.conf  
  
#### Want to see which server is the primary server?  
  
Pick any pg container and run  
```  
docker exec -it pgha-pg1-node1 patronictl -c /pgha/config/patroni.conf list  
```  
  
```  
+ Cluster: pgha_cluster (7364915463012110378) +----+-----------+  
| Member | Host | Role | State | TL | Lag in MB |  
+-----------+-----------+---------+-----------+----+-----------+  
| pg1-node1 | pg1-node1 | Leader | running | 3 | |  
| pg1-node2 | pg1-node2 | Replica | streaming | 3 | 0 |  
| pg1-node3 | pg1-node3 | Replica | streaming | 3 | 0 |  
| pg1-node4 | pg1-node4 | Replica | streaming | 3 | 0 |  
| pg1-node5 | pg1-node5 | Replica | streaming | 3 | 0 |  
| pg1-node6 | pg1-node6 | Replica | streaming | 3 | 0 |  
| pg1-node7 | pg1-node7 | Replica | streaming | 3 | 0 |  
| pg1-node8 | pg1-node8 | Replica | streaming | 3 | 0 |  
| pg1-node9 | pg1-node9 | Replica | streaming | 3 | 0 |  
+-----------+-----------+---------+-----------+----+-----------+  
```  
  
#### Want to promote a server to be Leader ?  
  
Pick any running pg container and run ...  
  
```  
docker exec -it pgha-pg1-node1 patronictl -c /pgha/config/patroni.conf switchover --leader=pg1-node1 --candidate=pg1-node4 --force  
```  
  
```  
+ Cluster: pgha_cluster (7364915463012110378) +----+-----------+  
| Member | Host | Role | State | TL | Lag in MB |  
+-----------+-----------+---------+-----------+----+-----------+  
| pg1-node1 | pg1-node1 | Replica | streaming | 5 | 0 |  
| pg1-node2 | pg1-node2 | Replica | streaming | 5 | 0 |  
| pg1-node3 | pg1-node3 | Replica | streaming | 5 | 0 |  
| pg1-node4 | pg1-node4 | Leader | running | 5 | |  
| pg1-node5 | pg1-node5 | Replica | streaming | 5 | 0 |  
| pg1-node6 | pg1-node6 | Replica | streaming | 5 | 0 |  
| pg1-node7 | pg1-node7 | Replica | streaming | 5 | 0 |  
| pg1-node8 | pg1-node8 | Replica | streaming | 5 | 0 |  
| pg1-node9 | pg1-node9 | Replica | streaming | 5 | 0 |  
+-----------+-----------+---------+-----------+----+-----------+  
```  
  
  
#### Want to see your current config in dcs?  
  
Pick any running pg container and run ...  
  
```  
docker exec -it pgha-pg1-node1 patronictl -c /pgha/config/patroni.conf show-config  
```  
  
```  
loop_wait: 10  
maximum_lag_on_failover: 1048576  
postgresql:  
parameters:  
archive_command: pgbackrest --config=/pgha/config/pgbackrest.conf --stanza=pgha_db archive-push "/pgdata/16/pg_wal/%f"  
archive_mode: true  
archive_timeout: 1800s  
hot_standby: true  
log_filename: postgresql-%Y-%m-%d-%a.log  
log_line_prefix: '%m [%r] [%p]: [%l-1] user=%u,db=%d,host=%h '  
log_lock_waits: 'on'  
log_min_duration_statement: 1000  
logging_collector: 'on'  
max_replication_slots: 10  
max_wal_senders: 10  
max_wal_size: 1GB  
wal_keep_size: 4096  
wal_level: logical  
wal_log_hints: true  
recovery_conf:  
recovery_target_timeline: latest  
restore_command: pgbackrest --config=/pgha/config/pgbackrest.conf --stanza=pgha_db archive-get %f %p  
use_pg_rewind: true  
use_slots: true  
retry_timeout: 10  
ttl: 30  
```  
  
### etcd Info  
  
As mentioned earlier, the etcd containers are created based on the number of nodes in your cluster.  
  
We are using a newer version of etcd which means some changes to commands. To make things a little easier to do, the docker-compose file creates an ENDPOINTS environment variable inside the container so you don't have to create  
one every time you want to check etcd.  
  
For example check the status like this using the ENDPOINTS env  
  
Log onto any etcd container  
  
```  
docker exec -it pgha-etcd2 /bin/bash  
```  
  
and run  
  
```  
etcdctl --write-out=table --endpoints=$ENDPOINTS endpoint status  
```  
  
```  
+------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+  
| ENDPOINT | ID | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |  
+------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+  
| etcd1:2380 | 3881244e074acb1d | 3.5.13 | 82 kB | false | false | 2 | 193 | 193 | |  
| etcd2:2380 | 328bbe88afec63c5 | 3.5.13 | 82 kB | false | false | 2 | 193 | 193 | |  
| etcd3:2380 | db322f4bdb3697fb | 3.5.13 | 82 kB | true | false | 2 | 193 | 193 | |  
| etcd4:2380 | f61ed83a70a5bdbc | 3.5.13 | 82 kB | false | false | 2 | 193 | 193 | |  
| etcd5:2380 | c0d9e8e50aa266f2 | 3.5.13 | 82 kB | false | false | 2 | 193 | 193 | |  
+------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+  
```  
  
  
  
  
  
  
## Connecting to the databases  
  
Rather than using a third party tool such as haproxy to manage and load balance our connections to the database, we can use Postgreges libpq to achieve similar results without the overhead. By customizing our connection string w  
e can do the following.  
  
Connect to a primary (r/w) node from the list of hosts specified in the string. In our docker environment, we are running this command from inside one of the containers.  
  
```  
psql 'host=pg1-node1,pg1-node2,pg1-node3,pg1-node4,pg1-node5,pg1-node6,pg1-node7,pg1-node8,pg1-node9 user=postgres password=postgres target_session_attrs=primary'  
```  
  
```  
psql 'host=pg1-node1,pg1-node2,pg1-node3,pg1-node4,pg1-node5,pg1-node6,pg1-node7,pg1-node8,pg1-node9 user=postgres password=postgres target_session_attrs=primary'  
  
psql (16.2 (Ubuntu 16.2-1.pgdg22.04+1))  
Type "help" for help.  
  
postgres=# select pg_is_in_recovery();  
pg_is_in_recovery  
-------------------  
f  
(1 row)  
```  
  
To perform a similar connection from outside the container, we specify localhosts and the mapped port for the container.  
In the below example, we also set the option of **load_balance_hosts=random** which will pick any of the hosts specified at random and specify **target_session_attrs=standby** which will connect to a standby / replica.  
  
```  
psql 'host=localhost,localhost,localhost,localhost,localhost,localhost,localhost,localhost,localhost port=50551,50552,50553,50554,50555,50556,50557,50558,50559 user=postgres password=postgres load_balance_hosts=random target_ses  
sion_attrs=standby'  
  
psql (16.2 (Ubuntu 16.2-1.pgdg22.04+1))  
Type "help" for help.  
  
postgres=# select pg_is_in_recovery();  
pg_is_in_recovery  
-------------------  
t  
(1 row)  
```  
  
Additionally, you can select a host from the connection list of hosts at random with the following option in your connection string.  
  
```  
load_balance_hosts=random  
```  
  
In future versions, a weight option is expected.  
  
  
The following are the target session attribute options currently available in Postgres 16. For the online documentation, visit https://www.postgresql.org/docs/current/libpq-connect.html  
  
  
### target_session_attrs  
  
This option determines whether the session must have certain properties to be acceptable. It's typically used in combination with multiple host names to select the first acceptable alternative among several hosts. There are six m  
odes:  
  
#### any (default)  
any successful connection is acceptable  
  
#### read-write  
session must accept read-write transactions by default (that is, the server must not be in hot standby mode and the default_transaction_read_only parameter must be off)  
  
#### read-only  
session must not accept read-write transactions by default (the converse)  
  
#### primary  
server must not be in hot standby mode  
  
#### standby  
server must be in hot standby mode  
  
#### prefer-standby  
first try to find a standby server, but if none of the listed hosts is a standby server, try again in any mode  
  
  
## Cleaning up when you are done  
  
When you are done with the containers and no longer need them you can perform the following which will stop and remove the containers.  
  
From within the Docker folder where your docker-compose.yaml file is execute the following.  
  
```  
docker compose down  
```  
  
If you wish to remove the actual volumes created for each container, execute the following.  
  
```  
docker volume rm $(docker volume ls | grep dockerpgha | awk '{print $2}')  
```  
  
Please note that removing the volumes will remove any data you had saved. If you decide to leave them in place, you can recreate the containers  
and it will use the data that in those volumes.  
  
Also, make sure the docker volume rm above is using grep for specific volume names. If you are addressing different volumes modify your grep command above.
