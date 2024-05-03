# DockerPgHA

The following is a first go at building out a simulated multi data center Postgres 16 on Ubuntu 20.04 using Patroni, etcd and Docker. Optionally, pgbackrest as a backup solution as well.

There is no haproxy in this environment. The use of libpq and its new random feature works great.

This will spin up 5 etcd containers and 6 postgres containers. Prior to starting the containers, we create 3 separate networks where a pair of postgres containers will run in a given network. This is simply to simulate multi data centers.

The etcd folder contains the Docker file necessary to create the image for the etcd builds. Since the ubuntu package does not have the latest version of etcd ( as of 4/30/24 ), we use the latest from Google to build our image.

The pgpatroni folder contains the Docker file necessary to create an Ubunto 20.04 image running Postgresql 16 and Patroni.

The pgbackrest folder has the necessary files to create the pgbackrest container so we can backup the database.

Lastly, we have the main folder that contains the docker-compose.yaml file.
It is a big file but do not let that put you off. The compose file creates 5 etcd containers and 6 postgres containers. You just need to focus on 1 etcd service and 1 pg service in the compose file. The rest are just duplicates with minor changes.

## TL;DR;
From inside the etcd folder  ...

``` docker build -t pgha-etcd-3.5 . ```

From inside the pgpatroni folder ...

```docker build -t pgha-pg16-patroni .```

From inside the pgbackrest folder ...

```docker build -t pgha-pgbackrest .```

From the main folder

```./genCompose -n pg -d 3 -p 2 -v 16```

FYI, this generates a docker-compose.yaml file for you.

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
     

Then

```docker-compose create```

Fololowed by

```docker-compose start```

Lastly ...

```docker exec -it pgha-pgbackrest su -c 'pgbackrest --stanza=${STANZA_NAME} stanza-create' postgres```



## The long part now ....

### SSH requirements
In order for pgbackrest to work and the ability to ssh between containers, We need to be trusted across all the servers.
Prior to building your images, generate an ssh key that you will copy into all the containers. Or, you can use the ones in this repo which reside in the main folder. The include the public, private and authorised_keys .

**Don't panic**. The ssh keys in this repo were generated inside a docker container and have no existence outside of them and have since been trashed. Feel free to use them.

On a side note, the ```entrypoint.sh``` script adds ```StrictHostKeyChecking no``` to the ```/stc/ssh/ssh_config``` file so you do not need to worry about responding to ssh prompts. Especially if using pgbackrest.

Also, sshd is started at the command line ```/usr/sbin/sshd``` rather than running under systemd.

### Generate the images

Rather than include the build commands in the compose file, We will build our images directly using the cli

From inside the etcd folder  ...

``` docker build -t pgha-etcd-3.5 . ```

From inside the pgpatroni folder ...

```docker build -t pgha-pg16-patroni .```

From inside the pgbackrest folder ...

```docker build -t pgha-pgbackrest .```


If successful, you should be able to see the images in your local repository

```
docker images

REPOSITORY              TAG            IMAGE ID       CREATED         SIZE
pgha-pg16-patroni       latest         bf7e8fa50dc4   2 hours ago     548MB
pgha-pgbackrest         latest         23765655a0d5   2 hours ago     314MB
pgha-etcd-3.5           latest         edab3b23c2c4   3 hours ago     344MB
```

### Generate a docker-compose

```./genCompose```

### Bring up the environment

Once the images are ready, from the main folder you can run ...

```docker-compose create```

then

```docker-compose start```

You could run ```docker-compose up``` but that leaves the terminal occupied while running the containers

After you start the containers you should see the following containers by running ```docker ps```



```
CONTAINER ID   IMAGE               COMMAND                  CREATED         STATUS         PORTS                               NAMES
b76d6f740ca4   pgha-pg16-patroni   "/entrypoint.sh"         9 minutes ago   Up 9 minutes   0.0.0.0:50554->5432/tcp             pgha-pg2-node2
d4f0e85aabfa   pgha-pg16-patroni   "/entrypoint.sh"         9 minutes ago   Up 9 minutes   0.0.0.0:50553->5432/tcp             pgha-pg2-node1
53b08390bcb1   pgha-pg16-patroni   "/entrypoint.sh"         9 minutes ago   Up 9 minutes   0.0.0.0:50556->5432/tcp             pgha-pg3-node2
a1158c720440   pgha-pg16-patroni   "/entrypoint.sh"         9 minutes ago   Up 9 minutes   0.0.0.0:50552->5432/tcp             pgha-pg1-node2
6b04443782ee   pgha-pg16-patroni   "/entrypoint.sh"         9 minutes ago   Up 9 minutes   0.0.0.0:50555->5432/tcp             pgha-pg3-node1
5199fd9a9f9f   pgha-pg16-patroni   "/entrypoint.sh"         9 minutes ago   Up 9 minutes   0.0.0.0:50551->5432/tcp             pgha-pg1-node1
3a500b494e00   pgha-etcd-3.5       "/usr/bin/etcd --nam…"   9 minutes ago   Up 9 minutes   2380/tcp, 0.0.0.0:54693->2379/tcp   pgha-etcd3
41adaefee600   pgha-pgbackrest     "/entrypoint.sh"         9 minutes ago   Up 9 minutes                                       pgha-pgbackrest
1e779370437c   pgha-etcd-3.5       "/usr/bin/etcd --nam…"   9 minutes ago   Up 9 minutes   2380/tcp, 0.0.0.0:54697->2379/tcp   pgha-etcd4
4fdbc46eaaf5   pgha-etcd-3.5       "/usr/bin/etcd --nam…"   9 minutes ago   Up 9 minutes   2380/tcp, 0.0.0.0:54696->2379/tcp   pgha-etcd5
e79d10648177   pgha-etcd-3.5       "/usr/bin/etcd --nam…"   9 minutes ago   Up 9 minutes   2380/tcp, 0.0.0.0:54694->2379/tcp   pgha-etcd2
7313e0bd2203   pgha-etcd-3.5       "/usr/bin/etcd --nam…"   9 minutes ago   Up 9 minutes   2380/tcp, 0.0.0.0:54695->2379/tcp   pgha-etcd1
```

### Create the stanza for backups

```docker exec -it pgha-pgbackrest su -c 'pgbackrest --stanza=${STANZA_NAME} stanza-create' postgres```



### More info to be added.

How to do backup
How to restore




## Patroni

The patroni config file is in /pgha/config/patroni.conf

#### Want to see which server is the primary server?

Pick any pg container and run 
```docker exec -it pgha-pg3-node2 patronictl -c /pgha/config/patroni.conf list```

```
+ Cluster: pgha_cluster (7364639776149565470) +----+-----------+
| Member    | Host      | Role    | State     | TL | Lag in MB |
+-----------+-----------+---------+-----------+----+-----------+
| pg1-node1 | pg1-node1 | Replica | streaming |  1 |         0 |
| pg1-node2 | pg1-node2 | Replica | streaming |  1 |         0 |
| pg2-node1 | pg2-node1 | Replica | streaming |  1 |         0 |
| pg2-node2 | pg2-node2 | Leader  | running   |  1 |           |
| pg3-node1 | pg3-node1 | Replica | streaming |  1 |         0 |
| pg3-node2 | pg3-node2 | Replica | streaming |  1 |         0 |
+-----------+-----------+---------+-----------+----+-----------+
```

#### Want to promote a server to be Leader ?

Pick any running pg container and run ...

```docker exec -it pgha-pg3-node2 patronictl -c /pgha/config/patroni.conf failover --candidate=pg1-node1 --force```

```
+ Cluster: pgha_cluster (7364639776149565470) +----+-----------+
| Member    | Host      | Role    | State     | TL | Lag in MB |
+-----------+-----------+---------+-----------+----+-----------+
| pg1-node1 | pg1-node1 | Leader  | running   |  2 |           |
| pg1-node2 | pg1-node2 | Replica | streaming |  2 |         0 |
| pg2-node1 | pg2-node1 | Replica | streaming |  2 |         0 |
| pg2-node2 | pg2-node2 | Replica | streaming |  2 |         0 |
| pg3-node1 | pg3-node1 | Replica | streaming |  2 |         0 |
| pg3-node2 | pg3-node2 | Replica | streaming |  2 |         0 |
+-----------+-----------+---------+-----------+----+-----------+
```


#### Want to see your current config ?

Pick any running pg container and run ...

```docker exec -it pgha-pg3-node2 patronictl -c /pgha/config/patroni.conf show-config```

```
loop_wait: 10
maximum_lag_on_failover: 1048576
postgresql:
  parameters:
    archive_command: /bin/true
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
  use_pg_rewind: true
  use_slots: true
retry_timeout: 10
ttl: 30
```


## Connecting without haproxy

I am not a fan of haproxy, it works well and does what it is supposed to do. However, a lot can be done with the postgres connection string and features in pg16 libpq.

For example ...

Based on our patronictl list output, we know that pg1 is the leader. So, with the following connection string we can specify all our pg hosts and connect to the primary from inside the container.

```psql 'host=pg1-node1,pg1-node2,pg2-node1,pg2-node2,pg3-node1,pg3-node2 user=postgres password=postgres target_session_attrs=primary'```

Connecting from the host outside the container you could specify the connection string like this

```psql 'host=localhost,localhost,localhost,localhost,localhost,localhost  port=50551,50552,50553,50554,50555,50556 user=postgres password=postgres load_balance_hosts=random target_session_attrs=standby'```

Where it will connect using the specfied ports and select a random standby out of the 6 servers in the connection string.

If I wanted to connect to a replica and have a random server selected from the host list, you would run

```psql 'host=pg1-node1,pg1-node2,pg2-node1,pg2-node2,pg3-node1,pg3-node2 user=postgres password=postgres target_session_attrs=standby load_balance_hosts=random'```

As you can see here, running the command several times shows a client connection to a different pg server.

```
root@pg2-node2:/# psql 'host=pg1-node1,pg1-node2,pg2-node1,pg2-node2,pg3-node1,pg3-node2 user=postgres password=postgres target_session_attrs=standby load_balance_hosts=random' -c "SELECT inet_server_addr()"
 inet_server_addr
------------------
 172.10.0.12
(1 row)

root@pg2-node2:/# psql 'host=pg1-node1,pg1-node2,pg2-node1,pg2-node2,pg3-node1,pg3-node2 user=postgres password=postgres target_session_attrs=standby load_balance_hosts=random' -c "SELECT inet_server_addr()"
 inet_server_addr
------------------
 172.30.0.7
(1 row)

root@pg2-node2:/# psql 'host=pg1-node1,pg1-node2,pg2-node1,pg2-node2,pg3-node1,pg3-node2 user=postgres password=postgres target_session_attrs=standby load_balance_hosts=random' -c "SELECT inet_server_addr()"
 inet_server_addr
------------------
 172.10.0.11
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




## Run pgbackrest and create a backup

If you decide to use pgbackrest, start the container as noted above.

This is what our ssh setup was needed for

log into the container

```docker exec -it pgha-pgbackrest /bin/bash```

**NOTE** Backup commands need to run as user postgres

First thing's first,

#### Create the stanza for the first time.

We have some environment variables pre set to make this easier and consistent

```su -c 'pgbackrest --stanza=${STANZA_NAME} stanza-create' postgres```

We ran the above command as user root but executed it as postgres.  We could ```su - postgres``` and run

```pgbackrest --stanza=${STANZA_NAME} stanza-create```

you get some output and at the end you should see

```
2024-04-30 20:36:55.504 P00   INFO: stanza-create for stanza 'pg_ha_db' on repo1
2024-04-30 20:36:56.123 P00   INFO: stanza-create command end: completed successfully (5079ms)
```

#### Create a backup

##### initial setup

Remember earlier we created a file called ```/pg_ha/config/patroni_with_pgbackrest.readme``` inside of the postgres container?  Well, it's time to use that file.

Log onto any of the running postgres servers

``` docker exec -it pgha-pg2-node2 /bin/bash```

cat the file so you can cut and paste

```cat /pg_ha/config/patroni_with_pgbackrest.readme```

Read the comments at the top of the file.

copy the following out of the file

```
loop_wait: 10
maximum_lag_on_failover: 1048576
postgresql:
  parameters:
    archive_command: pgbackrest --stanza=pg_ha_db archive-push /pgdata/pg_wal/%f
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
    restore_command: pgbackrest --config=/pg_ha/config/pgbackrest.conf --stanza=pg_ha_db archive-get %f %p
  use_pg_rewind: true
  use_slots: true
retry_timeout: 10
ttl: 30
```

Now it's time to make the changes to the DCS

run ```patronictl -c $PATRONI_CFG edit-config```

Replace the content of the edit config screen with the copied content above.
Save your changes.

You will be prompted

```
Apply these changes? [y/N]: y
Configuration changed
```

if you run ```patronictl -c $PATRONI_CFG show-config``` you will see the changes in place.

Now we are ready to createthe first backup

#### Back on the pgha-backrest container


run ```su -c 'pgbackrest --stanza=${STANZA_NAME} --type=full backup' postgres```

You should get a long output and at the end you should see something like

```
2024-04-30 20:53:37.264 P00   INFO: check archive for segment(s) 000000020000000000000009:000000020000000000000009
2024-04-30 20:53:37.477 P00   INFO: new backup label = 20240430-205319F
2024-04-30 20:53:37.513 P00   INFO: full backup size = 22.2MB, file total = 974
2024-04-30 20:53:37.513 P00   INFO: backup command end: completed successfully (22586ms)
2024-04-30 20:53:37.513 P00   INFO: expire command begin 2.51: --exec-id=54-a1a93ee4 --log-level-console=detail --log-level-file=detail --repo1-path=/pg_ha/pgbackrest --repo1-retention-archive-type=full --repo1-retention-full=2 --stanza=pg_ha_db
2024-04-30 20:53:37.921 P00   INFO: expire command end: completed successfully (408ms)
```

#### View backup info

To view backup info just run

```
su -c 'pgbackrest --stanza=${STANZA_NAME} info' postgres
```

Which generates something like

```
stanza: pg_ha_db
    status: ok
    cipher: none

    db (current)
        wal archive min/max (16): 000000020000000000000008/000000020000000000000009

        full backup: 20240430-205319F
            timestamp start/stop: 2024-04-30 20:53:19+00 / 2024-04-30 20:53:37+00
            wal start/stop: 000000020000000000000009 / 000000020000000000000009
            database size: 22.2MB, database backup size: 22.2MB
            repo1: backup set size: 2.9MB, backup size: 2.9MB

