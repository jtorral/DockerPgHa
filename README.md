# DockerPgHA

The following is for dockerizing a simulated multi data center Postgres 16 on Ubuntu 20.04 using Patroni, etcd,  pgbackrest and Docker.

You have the ability to generate docker-compose files for x number of data centers and x number of nodes per data center.

Below is a TL;DR section followed by a more detailed explanation of what is happening.



## TL;DR;

From inside the etcd folder  ...

``` docker build -t pgha-etcd-3.5 . ```

From inside the pgpatroni folder ...

```docker build -t pgha-pg16-patroni .```

From inside the pgbackrest folder ...

```docker build -t pgha-pgbackrest .```

From the main folder

We will generate containers for 2 centers with 2 nodes each using the docker-compose file generator
```./genCompose -npg -d2 -p2 -v16```

```
Usage:
       ./genCompose [OPTION]

       -d Number of data centers to simulate. (default = 1)
       -p number of nodes per data center. (default = 2)
       -n Prefix name to use for db container.
       -v Postgres Major version number. i.e 16

       Number of db nodes is capped at 9. So (-d * -p) should be <= 9
       Number of etcd nodes are calculated on (-d * -p ) / 2 + 1
```

From the main folder

```docker-compose create```

Fololowed by

```docker-compose start```

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
in addition to the buildingblock packages above, the folloing are also installed. Feel free to modiify the Docker file and remove packages you don't feel you need for a lighter footprint.

```
  && apt-get install -y wget \
  && apt-get install -y curl \
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

sshd is started at the command line ```/usr/sbin/sshd``` rather than running under systemd.

### Docker images

The generated images listed below is what we will use.

```
docker images

REPOSITORY              TAG            IMAGE ID       CREATED         SIZE
pgha-pg16-patroni       latest         bf7e8fa50dc4   2 hours ago     548MB
pgha-pgbackrest         latest         23765655a0d5   2 hours ago     314MB
pgha-etcd-3.5           latest         edab3b23c2c4   3 hours ago     344MB
```

### genCompose

The genCompose file lets you generate docker-compose.yaml files for your desired environment.
Some nifty features include the ability to

1. create the necessary number of etcd containers for the number of nodes you create.
2. If you specify multiple data centers, a priority to a specific network is given.
3. specify how many data centers4. how many nodes per data center.
4. name your postgres containers.

When naming a postghres container, it really means a prefix for the container name because genCompose will generate the name with a specific format.

For example,  If you where to specify the name **pg** and 2 datacenter with 2 nodes per data center, genCompose would create the following nodes.

1. pg1-node1
2. pg1-node2
3. pg2-node1
4. pg2-node2

You create a node name of "dude" you would get

dude1-node1  and so on ...

the number after the name prefix is synonymous with a data center. So, pg1 would reside in data center 1.

genCompose builds 3 networks within the docker environment,

1. net1
2. net2
3. net3

As each node gets added to the docker-compose file, priority is given to the network based on node name.

1. pg1 nodes would be prioritized to net1
2. pg2 nodes would be prioritized to net2
3. pg3 nodes would be prioritized to net3

Additional data centers woudl loop around net1 through 3.  
Feel free to modify the genCompose script and add additional netwrks and change the priority logic.

The script adds **depends_on** sections to the postgres and pgbackrest service.
Postgres depends on etcd services to be running prioir to starting
Postgres depends on pg1 postgres to be running as well.

Keep in mind, depends_on is not the best way to specify start up order. Health checks should be used.

Additionally, genCompose assigns static port mapping to postgres containers so you can consistently access them with the same connection string.

### The running environment

In this example, there is one data center with 9 nodes

```
CONTAINER ID   IMAGE             COMMAND                  CREATED             STATUS             PORTS                               NAMES
c83187335a3d   3bef0a1c14a4      "/entrypoint.sh"         About an hour ago   Up About an hour   0.0.0.0:50558->5432/tcp             pgha-pg1-node8
e6ab34c49d96   3bef0a1c14a4      "/entrypoint.sh"         About an hour ago   Up About an hour   0.0.0.0:50559->5432/tcp             pgha-pg1-node9
da696d20bde7   3bef0a1c14a4      "/entrypoint.sh"         About an hour ago   Up About an hour   0.0.0.0:50553->5432/tcp             pgha-pg1-node3
d055362db7aa   3bef0a1c14a4      "/entrypoint.sh"         About an hour ago   Up About an hour   0.0.0.0:50552->5432/tcp             pgha-pg1-node2
968ceb990f4f   3bef0a1c14a4      "/entrypoint.sh"         About an hour ago   Up About an hour   0.0.0.0:50556->5432/tcp             pgha-pg1-node6
dc7fc7aa2519   pgha-pgbackrest   "/entrypoint.sh"         About an hour ago   Up About an hour                                       pgha-pgbackrest
a1f85f977850   3bef0a1c14a4      "/entrypoint.sh"         About an hour ago   Up About an hour   0.0.0.0:50554->5432/tcp             pgha-pg1-node4
e80e26167b0c   3bef0a1c14a4      "/entrypoint.sh"         About an hour ago   Up About an hour   0.0.0.0:50557->5432/tcp             pgha-pg1-node7
8596dfc62104   3bef0a1c14a4      "/entrypoint.sh"         About an hour ago   Up About an hour   0.0.0.0:50555->5432/tcp             pgha-pg1-node5
b80a73f9bb4a   3bef0a1c14a4      "/entrypoint.sh"         About an hour ago   Up About an hour   0.0.0.0:50551->5432/tcp             pgha-pg1-node1
9728a711dee1   pgha-etcd-3.5     "/usr/bin/etcd --nam…"   About an hour ago   Up About an hour   2380/tcp, 0.0.0.0:52635->2379/tcp   pgha-etcd3
1a33819a0c11   pgha-etcd-3.5     "/usr/bin/etcd --nam…"   About an hour ago   Up About an hour   2380/tcp, 0.0.0.0:52637->2379/tcp   pgha-etcd1
db8dcedb06a6   pgha-etcd-3.5     "/usr/bin/etcd --nam…"   About an hour ago   Up About an hour   2380/tcp, 0.0.0.0:52634->2379/tcp   pgha-etcd2
afb30ebb7d4b   pgha-etcd-3.5     "/usr/bin/etcd --nam…"   About an hour ago   Up About an hour   2380/tcp, 0.0.0.0:52638->2379/tcp   pgha-etcd4
58f7baa8c01c   pgha-etcd-3.5     "/usr/bin/etcd --nam…"   About an hour ago   Up About an hour   2380/tcp, 0.0.0.0:52636->2379/tcp   pgha-etcd5
```


### entrypoint scripts

Some notes about the entrypoint scripts.

#### pgpatroni entrypoint details

This script will  
1. create patroni.conf 
2. create pgbackrest.conf
3. Check if it has to restore itself from backup
4. Remove strict host key checking from ssh config so no answering prompts is required

If the file /pgha/config/restoreme exists, the container will try and initialize itself from a restored backup. Additional action is required and detaile below.

#### pgbackrest entrypoint details

This script will
1. create pgbackrest.conf
2. Check for the presence of a required stanza and attempt top create it.

If the stanza does not exists, pgbackrest will attempt to create it 10 times with a 15 second sleep between each attempt.

You could manually create it with the following command.  **Remember all pgbackrest commands must be run as user postgres.**

```docker exec -it pgha-pgbackrest su -c 'pgbackrest --stanza=${STANZA_NAME} stanza-create' postgres```


#### Backup restores

If you log into a container and execute ```/pgha/config/restoremeOnStartup``` a trigger file named ```restoreme``` will be placed in the folder.

When the container is restarted, the presence of that trigger file will cause the data directory to be cleaned out and repopulated with the latest backup. 

Make sure to read the output from the restoremeOnStartup script.

**Run this on a Leader**

```
=======================================================================================================
Don't forget to shut down all replica nodes prior to restarting this one.

You will need to reinit the replicas to sync up with a newly restored primary with a different timeline
Below are the commands for reinitializing other cluster. Feel free to use or run your own
Reinitilaze the mebers after the restored server shows Leader and running status

patronictl -c /pgha/config/patroni.conf reinit pgha_cluster pg1-node2 --force
patronictl -c /pgha/config/patroni.conf reinit pgha_cluster pg1-node3 --force
patronictl -c /pgha/config/patroni.conf reinit pgha_cluster pg1-node4 --force
patronictl -c /pgha/config/patroni.conf reinit pgha_cluster pg1-node5 --force
patronictl -c /pgha/config/patroni.conf reinit pgha_cluster pg1-node6 --force
patronictl -c /pgha/config/patroni.conf reinit pgha_cluster pg1-node7 --force
patronictl -c /pgha/config/patroni.conf reinit pgha_cluster pg1-node8 --force
patronictl -c /pgha/config/patroni.conf reinit pgha_cluster pg1-node9 --force

=======================================================================================================
```

#### Want to perform a backup ?

```docker exec -it pgha-pgbackrest su -c 'pgbackrest --stanza=${STANZA_NAME} --type=full backup' postgres```

```
.
.
.
2024-05-04 01:32:39.073 P00   INFO: check archive for segment(s) 000000050000000000000013:000000050000000000000013
2024-05-04 01:32:39.283 P00   INFO: new backup label = 20240504-013221F
2024-05-04 01:32:39.320 P00   INFO: full backup size = 29.5MB, file total = 1275
2024-05-04 01:32:39.320 P00   INFO: backup command end: completed successfully (24286ms)
2024-05-04 01:32:39.320 P00   INFO: expire command begin 2.51: --exec-id=3240-c9b97e1e --log-level-console=detail --log-level-file=detail --repo1-path=/pgha/pgbackrest --repo1-retention-archive-type=full --repo1-retention-full=2 --stanza=pgha_db
2024-05-04 01:32:39.326 P00 DETAIL: repo1: 16-1 archive retention on backup 20240503-231613F, start = 000000010000000000000006
2024-05-04 01:32:39.329 P00   INFO: repo1: 16-1 remove archive, start = 000000010000000000000001, stop = 000000010000000000000005
2024-05-04 01:32:40.131 P00   INFO: expire command end: completed successfully (811ms)
```

#### Want to check you rbackup repo?

```docker exec -it pgha-pgbackrest su -c 'pgbackrest --stanza=${STANZA_NAME} info' postgres```

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
```docker exec -it pgha-pg1-node1 patronictl -c /pgha/config/patroni.conf list```

```
+ Cluster: pgha_cluster (7364915463012110378) +----+-----------+
| Member    | Host      | Role    | State     | TL | Lag in MB |
+-----------+-----------+---------+-----------+----+-----------+
| pg1-node1 | pg1-node1 | Leader  | running   |  3 |           |
| pg1-node2 | pg1-node2 | Replica | streaming |  3 |         0 |
| pg1-node3 | pg1-node3 | Replica | streaming |  3 |         0 |
| pg1-node4 | pg1-node4 | Replica | streaming |  3 |         0 |
| pg1-node5 | pg1-node5 | Replica | streaming |  3 |         0 |
| pg1-node6 | pg1-node6 | Replica | streaming |  3 |         0 |
| pg1-node7 | pg1-node7 | Replica | streaming |  3 |         0 |
| pg1-node8 | pg1-node8 | Replica | streaming |  3 |         0 |
| pg1-node9 | pg1-node9 | Replica | streaming |  3 |         0 |
+-----------+-----------+---------+-----------+----+-----------+
```

#### Want to promote a server to be Leader ?

Pick any running pg container and run ...

```docker exec -it pgha-pg1-node1 patronictl -c /pgha/config/patroni.conf failover --candidate=pg1-node4 --force```

```
+ Cluster: pgha_cluster (7364915463012110378) +----+-----------+
| Member    | Host      | Role    | State     | TL | Lag in MB |
+-----------+-----------+---------+-----------+----+-----------+
| pg1-node1 | pg1-node1 | Replica | streaming |  5 |         0 |
| pg1-node2 | pg1-node2 | Replica | streaming |  5 |         0 |
| pg1-node3 | pg1-node3 | Replica | streaming |  5 |         0 |
| pg1-node4 | pg1-node4 | Leader  | running   |  5 |           |
| pg1-node5 | pg1-node5 | Replica | streaming |  5 |         0 |
| pg1-node6 | pg1-node6 | Replica | streaming |  5 |         0 |
| pg1-node7 | pg1-node7 | Replica | streaming |  5 |         0 |
| pg1-node8 | pg1-node8 | Replica | streaming |  5 |         0 |
| pg1-node9 | pg1-node9 | Replica | streaming |  5 |         0 |
+-----------+-----------+---------+-----------+----+-----------+
```


#### Want to see your current config in dcs?

Pick any running pg container and run ...

```docker exec -it pgha-pg1-node1 patronictl -c /pgha/config/patroni.conf show-config```

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

We are using a newer versionof etcd which means some changes to commands.  To make things a little easier to do, the docker-compose file creates and ENDPOINTS environment variable insiode the container so you don't have to create one everytime you want to check etcd.

For example check the status like this using the ENDPOINTS env

Log onto any etcd container

```docker exec -it pgha-etcd2 /bin/bash```

and run

```etcdctl --write-out=table --endpoints=$ENDPOINTS endpoint status```

```
+------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|  ENDPOINT  |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| etcd1:2380 | 3881244e074acb1d |  3.5.13 |   82 kB |     false |      false |         2 |        193 |                193 |        |
| etcd2:2380 | 328bbe88afec63c5 |  3.5.13 |   82 kB |     false |      false |         2 |        193 |                193 |        |
| etcd3:2380 | db322f4bdb3697fb |  3.5.13 |   82 kB |      true |      false |         2 |        193 |                193 |        |
| etcd4:2380 | f61ed83a70a5bdbc |  3.5.13 |   82 kB |     false |      false |         2 |        193 |                193 |        |
| etcd5:2380 | c0d9e8e50aa266f2 |  3.5.13 |   82 kB |     false |      false |         2 |        193 |                193 |        |
+------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```






## Connecting without haproxy

I am not a fan of haproxy, it works well and does what it is supposed to do. However, a lot can be done with the postgres connection string and features in pg16 libpq.

For example ...

We can list all our nodes in the connection string and connect to the primary from inside a container

```psql 'host=pg1-node1,pg1-node2,pg1-node3,pg1-node4,pg1-node5,pg1-node6,pg1-node7,pg1-node8,pg1-node9 user=postgres password=postgres target_session_attrs=primary'```

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


Connecting from the host outside the container you could specify the connection string to randomly pick a standby server

```
psql 'host=localhost,localhost,localhost,localhost,localhost,localhost,localhost,localhost,localhost  port=50551,50552,50553,50554,50555,50556,50557,50558,50559 user=postgres password=postgres load_balance_hosts=random target_session_attrs=standby'

psql (16.2 (Ubuntu 16.2-1.pgdg22.04+1))
Type "help" for help.

postgres=# select pg_is_in_recovery();
 pg_is_in_recovery
-------------------
 t
(1 row)
```

The following are the target session attribute options currently available.

### target_session_attrs

This option determines whether the session must have certain properties to be acceptable. It's typically used in combination with multiple host names to select the first acceptable alternative among several hosts. There are six modes:

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


