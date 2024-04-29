# DockerPgHA

The following is a first go at building out a simulated multi data center Posgres 16 on Ubuntu 20.04 using Patroni and etcd using Docker. There is no haproxy in this environment. The use of libpq and it's new random feature works great.


This will spin up 5 etcd containers and 6 postgres container. Additionally, we create 3 separate networks where a pair of postgres containers will run in a given network. This is simply to simulate multi data centers. 

The etcd folder contains the Docker file necessary to create the image for the etcd builds.  
Since the ubunto package does not have the latest version of etcd, we use the latest from google http://storage.googleapis.com/etcd to build our image.

The pgpatroni folder contains the Docker file necsessary to create an Ubunto 20.04 image running Postgresql 16 and Patroni. Additionally, there is an entrypoint.sh that setsup the patroni config file to use.

Lastly, we have the main folder that contains the docker-compose.yaml file.
It is a big file but do not let that put you off. This compose file create 5 etcd containers and 6 postgres containers. You just need to focus on 1 etcd service and 1 pg service. The rest are just duplicates with minor changes.

### Create networks

Create your 3 networks in Docker. This is to simulate 3 different data centers

```
docker network create --subnet=172.10.0.0/16 dockerNet1
docker network create --subnet=172.20.0.0/16 dockerNet2
docker network create --subnet=172.30.0.0/16 dockerNet3
```

### Generate the images

Rather than include the build commands in the compose file, We will build our images directly using the cli

From inside the etcd folder  ...

``` docker build -t etcd-3.5 . ```

From inside the pgpatroni folder ...

```docker build -t pg16-patroni .```

If succesfull, you should be able to see the images in your local rpository

```
REPOSITORY              TAG            IMAGE ID       CREATED             SIZE
pg16-patroni            latest         783231a84c8b   About an hour ago   548MB
etcd-3.5                latest         139a9ba47d03   3 days ago          344MB
```

### Bring up the environment

Once the images are ready, from the main folder you can run ...

```docker-compose up```

or 

```docker-compose create```

Which will create the following containers

```
CONTAINER ID   IMAGE          COMMAND                  CREATED          STATUS          PORTS                               NAMES
e16943968e6d   pg16-patroni   "/entrypoint.sh"         56 minutes ago   Up 56 minutes   0.0.0.0:50553->5432/tcp             pg3-container
7d34d1f66271   pg16-patroni   "/entrypoint.sh"         56 minutes ago   Up 56 minutes   0.0.0.0:50555->5432/tcp             pg5-container
e93e3be1fe56   pg16-patroni   "/entrypoint.sh"         56 minutes ago   Up 56 minutes   0.0.0.0:50554->5432/tcp             pg4-container
03dbf02b198b   pg16-patroni   "/entrypoint.sh"         56 minutes ago   Up 56 minutes   0.0.0.0:50552->5432/tcp             pg2-container
40afcfdc1f12   pg16-patroni   "/entrypoint.sh"         56 minutes ago   Up 56 minutes   0.0.0.0:50556->5432/tcp             pg6-container
ac2e2f70591c   pg16-patroni   "/entrypoint.sh"         56 minutes ago   Up 56 minutes   0.0.0.0:50551->5432/tcp             pg1-container
4856e0f8dd9a   etcd-3.5       "/usr/bin/etcd --nam…"   56 minutes ago   Up 56 minutes   2380/tcp, 0.0.0.0:51947->2379/tcp   etcd-5-container
ca4769fdb361   etcd-3.5       "/usr/bin/etcd --nam…"   56 minutes ago   Up 56 minutes   2380/tcp, 0.0.0.0:51946->2379/tcp   etcd-4-container
0112f544ca7b   etcd-3.5       "/usr/bin/etcd --nam…"   56 minutes ago   Up 56 minutes   2380/tcp, 0.0.0.0:51945->2379/tcp   etcd-3-container
ede19e9519b9   etcd-3.5       "/usr/bin/etcd --nam…"   56 minutes ago   Up 56 minutes   2380/tcp, 0.0.0.0:51944->2379/tcp   etcd-2-container
b4e045936807   etcd-3.5       "/usr/bin/etcd --nam…"   56 minutes ago   Up 56 minutes   2380/tcp, 0.0.0.0:51943->2379/tcp   etcd-1-container
```

### Brief overview

To keep things simple and easy to follow the following approach was taken. 

Container names have the word container appended to them. 
Postgres containers are named pg1 through pg6 with a somewhat related exposed port fro access from outside of the containers
All exposed ports start with with 5055 and the pg container number at the end. So to access pg4 externally, you would use port 50554. To access pg6, 50556 and so on.

```psql -h localhost -p 50554 -U postgres```

Would grant youi psql access to the pg4 container.

You can also just exec into the container if you wish

```docker exec -t pg4 /bin/bash```

### Check Patroni status

The patroni config file is in /pg_ha/config/patroni.conf

You can log exec into a container and run 

```
docker exec -it pg5-container /bin/bash

patronictl -c $PATRONI_CFG list

+ Cluster: pg_ha_cluster (7363343997940285464) --------+
| Member | Host | Role    | State     | TL | Lag in MB |
+--------+------+---------+-----------+----+-----------+
| pg1    | pg1  | Leader  | running   | 10 |           |
| pg2    | pg2  | Replica | streaming | 10 |         0 |
| pg3    | pg3  | Replica | streaming | 10 |         0 |
| pg4    | pg4  | Replica | streaming | 10 |         0 |
| pg5    | pg5  | Replica | streaming | 10 |         0 |
| pg6    | pg6  | Replica | streaming | 10 |         0 |
+--------+------+---------+-----------+----+-----------+
```

Or from outside the container


```docker exec -it pg5-container /usr/bin/patronictl -c /pg_ha/config/patroni.conf list```


## Connecting without haproxy

I am not a fan of haproxy, it works well and does what it is supposed to do. However, a lot can be done with the postgres connection string and features in pg16 libpq.

For example ...

Based on opur patronictl list output, we know that pg1 is the leader. So, with the following connection string we can specify all our pg hosts and connect to the primary.

```psql 'host=pg1,pg2,pg3,pg4,pg5,pg6 user=postgres password=postgres target_session_attrs=primary'```

```
psql (16.2 (Ubuntu 16.2-1.pgdg22.04+1))
Type "help" for help.

postgres=# \conninfo
You are connected to database "postgres" as user "postgres" on host "pg1" (address "172.10.0.7") at port "5432".
```

If I wanted to connect to a replica and have a random selection from my host list, I would run

```psql 'host=pg1,pg2,pg3,pg4,pg5,pg6 user=postgres password=postgres target_session_attrs=standby load_balance_hosts=random'```

As you can see here, running the command severla times shows a client connection to a different pg server.

```
postgres@pg5:~$ psql 'host=pg1,pg2,pg3,pg4,pg5,pg6 user=postgres password=postgres target_session_attrs=standby load_balance_hosts=random' -c "SELECT inet_server_addr()"
 inet_server_addr
------------------
 172.10.0.8
(1 row)

postgres@pg5:~$ psql 'host=pg1,pg2,pg3,pg4,pg5,pg6 user=postgres password=postgres target_session_attrs=standby load_balance_hosts=random' -c "SELECT inet_server_addr()"
 inet_server_addr
------------------
 172.10.0.11
(1 row)

postgres@pg5:~$ psql 'host=pg1,pg2,pg3,pg4,pg5,pg6 user=postgres password=postgres target_session_attrs=standby load_balance_hosts=random' -c "SELECT inet_server_addr()"
 inet_server_addr
------------------
 172.10.0.10
(1 row)

postgres@pg5:~$ psql 'host=pg1,pg2,pg3,pg4,pg5,pg6 user=postgres password=postgres target_session_attrs=standby load_balance_hosts=random' -c "SELECT inet_server_addr()"
 inet_server_addr
------------------
 172.10.0.12
(1 row)

postgres@pg5:~$ psql 'host=pg1,pg2,pg3,pg4,pg5,pg6 user=postgres password=postgres target_session_attrs=standby load_balance_hosts=random' -c "SELECT inet_server_addr()"
 inet_server_addr
------------------
 172.30.0.3
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




## Things to do ..

Still need to setup pgbackrest
