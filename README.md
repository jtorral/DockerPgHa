
# DockerPgHA  
  
The following is for dockerizing a simulated multi data center Postgres 16 on Ubuntu 20.04 using Patroni, etcd, pgbackrest and Docker.  
  
You have the ability to generate docker-compose files for x number of data centers and x number of nodes per data center.  
  
Below is a TL;DR section followed by a more detailed explanation of what is happening.  
  
  
## New changes made as noted here.  
  
### Naming changes  
First of all lets start with naming of service / containers  
  
Since this is intended to mimic multi data center environments everything is named in a way that makes identification easy.  
  
Each machine name has a data center name as part of its' host name. So if we name our machines "demo"  and specify x number of data centers, they will clearly be identifiable.


**pgha-etcd1-DC1-1**

**pgha-demo2-DC1-1**


If you wanted 3 machines with the hostname node per datacenter, each host would be named demo demo**x** per data center, where x would be 1,2 or 3.

**pgha-demo2-DC1-1**

The last number in the name represents the docker instance running. This allows you to have multiple containers with the same name just changing the last number to represent a unique set of docker instance.  For example ...

**pgha-demo2-DC1-1**
**pgha-demo2-DC1-2**

Above we have two sets running with the name demo but ending with 1 and 2. 1 would be one docker container environment, 2 would be a different one ut both share the same given host names of **demo**


 
### Networking  
  
We now create x number of networks based on the number of data centers. Plus a non data center network to host any external etcd nodes needed to ensure availability and quorum.

    Network ...  
      
    DC1 network is pgha-net-DC1-1 : Subnet: 172.18.0.0/16  
    DC2 (Non DC) network is pgha-net-DC2-1 : Subnet: 172.19.0.0/16

  
### Etcd distribution  

Etcd node calculation and distribution is completely different now when running genCompose to create the docker-compose file.

### An explanation is needed  ....

We will need etcd nodes outside the data centers to vote. This is so we can maintain quorum as others go down,  
So this is basically, the original number of etcd nodes needed, plus 1 additional set of external nodes.  

The additional number of external nodes is based number of etcd nodes per data center.  

We get the quorum needed based on this new number of nodes. 

Subtract how many nodes per data center which leaves us with how many extra nodes we need externally.  
  
For example ...

If you have 3 data centers with 2 etcd nodes per data center. That means a quorum of 4.  ( 3 * 2 ) / 2 + 1  
If all data centers but 1 were to go down, your are left with only 1 data center with 2 etcd nodes which is not enough to be a quorum.  

Now we throw in the external data center, you now have a total of 3 original data centers + the external data center which equals 4.  

With 4 data centers, 2 etcd nodes per data center, that gives us a total of 8 and the quorum for 8, is ( 8 / 2 ) + 1 = 5.  That means  we need a total of 5 etcd nodes to have a quorum .
 
So a total of 5 etcd nodes -2 ( the number left in running in the remaining data center ) = 3. This means the external data center  will need 3 etcd nodes .

 
 
### pgbackrest  
  
Pgbackrest server gets placed on the non data center network  
  
  
### Added basic script for status  
  
This was a late night though so it needs to be improved. However, its a good start to getting info about containers.  I will be using other methods. This can take time if there are down systems. 
  
**pghastat**
  
produces the following ....

```
Please wait while we gather some data ...  
If there are down systems, this could take a few minues  
  
  
Summary ...  
  
Instance used to query env : pgha-demo1-DC1-1  
Patroni Leader : pgha-demo2-DC1-1  
Active Patroni nodes : 2  
Active Patroni members : pgha-demo1-DC1-1 pgha-demo2-DC1-1  
DC hosting Patroni Leader : DC1  
Docker containers in DC1 : pgha-demo2-DC1-1 pgha-demo1-DC1-1 pgha-etcd1-DC1-1  
Number of running data centers : 1  
Data center names : DC1  
  
  
  
Patroni cluster ...  
  
+ Cluster: pgha_cluster (7515114130521325610) --+-----------+----+-----------+  
| Member | Host | Role | State | TL | Lag in MB |  
+------------------+------------------+---------+-----------+----+-----------+  
| pgha-demo1-DC1-1 | pgha-demo1-dc1-1 | Replica | streaming | 1 | 0 |  
| pgha-demo2-DC1-1 | pgha-demo2-dc1-1 | Leader | running | 1 | |  
+------------------+------------------+---------+-----------+----+-----------+  
  
Network ...  
  
DC1 network is pgha-net-DC1-1 : Subnet: 172.18.0.0/16  
DC2 (Non DC) network is pgha-net-DC2-1 : Subnet: 172.19.0.0/16  
  
  
etcd member health ...  
  
+-----------------------+--------+------------+-------+  
| ENDPOINT | HEALTH | TOOK | ERROR |  
+-----------------------+--------+------------+-------+  
| pgha-etcd5-DC2-1:2379 | true | 4.28825ms | |  
| pgha-etcd1-DC1-1:2379 | true | 3.838178ms | |  
| pgha-etcd3-DC2-1:2379 | true | 2.981874ms | |  
| pgha-etcd2-DC2-1:2379 | true | 4.431776ms | |  
| pgha-etcd4-DC2-1:2379 | true | 4.490715ms | |  
+-----------------------+--------+------------+-------+  
  
etcd status ...  
  
+-----------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+  
| ENDPOINT | ID | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |  
+-----------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+  
| pgha-etcd1-DC1-1:2379 | f68cb3af0d6092d4 | 3.5.13 | 41 kB | false | false | 2 | 59 | 59 | |  
| pgha-etcd2-DC2-1:2379 | e238d861bf95b2ad | 3.5.13 | 41 kB | false | false | 2 | 59 | 59 | |  
| pgha-etcd4-DC2-1:2379 | 179144efdbfdd2db | 3.5.13 | 41 kB | false | false | 2 | 59 | 59 | |  
| pgha-etcd5-DC2-1:2379 | ad922e091dafc9fa | 3.5.13 | 41 kB | true | false | 2 | 59 | 59 | |  
| pgha-etcd3-DC2-1:2379 | c83f647c1cc92d38 | 3.5.13 | 41 kB | false | false | 2 | 59 | 59 | |  
+-----------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
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
-c number of Postgres nodes per data center. (default = 2)  
-e number of ETCD nodes per data center. (default = 1)  
-m Minimum number of data centers to support after a failure. (default = 1)  
-n Prefix name to use for db containers (lower case no special characters).  
-b Start patroni in background and keep container running even if it stops.  
Good for upgrades and maintenance tasks.  
  
  
-Number of db nodes is capped at 9. So (-d * -c) should be <= 9  
  
-By default, the minimum number of data centers that can remain running out of the number of data centers declared is 1. Meaning everything  
still works as long as 1 data center is active.  
This can be change by using -m option and specifying a value of 2 which would essentially only work with a minimum of 2 data centers running.  
  
-Keep in mind that if the majority of your data centers are down, you have bigger problems to worry about.
```  
  
Once you generate your docker-compose file with genCompose, it outputs some basic instructions similar to the following

    genCompose -d1 -c2 -n demo  
      
      
    Overview ...  
      
    Number of data centers: 1  
    Original number of ETCD nodes needed: 3  
    Original number od ETCD nodes needed for a quorum: 2  
    Original number od ETCD nodes to deploy per data center: 1  
    The number of data centers to maintain running after all others fail: 1  
    Number of external ETCD nodes needed outside of data centers to maintain a quorum: 2  
    Total ETCD nodes needed including the external ones: 5  
    The new number of nodes needed to maintain a quorum: 3  
      
      
      
    File docker-compose.yaml generated  
      
      
    To get started, run ...  
      
      
    docker-compose create  
    docker-compose start  
      
      
    To stop and delete the containers run ...  
      
      
    docker-compose down  
      
      
    To remove associated volumes for good run ...  
      
      
    docker volume rm $(docker volume ls | grep pgha- | awk '{print $2}')  
      
      
    Try running the foloowing for a deploy status ...  
      
    ./pghastat demo

  
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
  

  
  
### Backup and restores  
 
**This part of the documentation has not changed and is based on the old naming convention .  So don't be confused.**
  
There are two ways of restoring backups for these docker containers.  
  
First things first. Make sure you have backups.  
  
  
#### Method 1  
  
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
  
#### Method 2  
  
The other way to restore is using custom pgbackrest restore commands. This requires that the container stays running even if patroni is shut down. You can accomplish this by passing passing the option **-b** when you generate you  
r docker-compose file using genCompose.  
  
  
  
The **-b** will create the compose-file and indicate that when patroni starts, it is done so using nohup and then followed by a  
```  
tail -f /dev/null  
```  
which keeps the container up even when patroni is not running.  
  
  
#### A high level overview of the process is as follows:  
  
  
  
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

**proxysql has been added. I will detail that since I put that in a different repo**

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
  
  
