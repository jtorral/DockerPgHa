# DockerPgHA

The following is a first go at building out a simulated multi data center Posgres 16 on Ubuntu 20.04 using Patroni and etcd using Docker.

This will spin up 5 etcd containers and 6 postgres container. Additionally, we create 3 separate networks where a pair of postgres containers will run in a given network. This is simply to simulate multi data centers. 

The etcd folder contains the Docker file necessary to create the image for the etcd builds.  
Since the ubunto package does not have the latest version of etcd, we use the latest from google http://storage.googleapis.com/etcd to build our image.

The pgpatroni folder contains the Docker file necsessary to create an Ubunto 20.04 image running Postgresql 16 and Patroni. Additionally, there is an entrypoint.sh that setsup the patroni config file to use.

Lastly, we have the main folder that contains the docker-compose.yaml file.
It is a big file but do not let that put you off. This compose file create 5 etcd containers and 6 postgres containers. You just need to focus on 1 etcd service and 1 pg service. The rest are just duplicates with minor changes.

First things first,

Create your 3 networks in Docker

``` docker network create --subnet=172.10.0.0/16 dockerNet1```
```docker network create --subnet=172.20.0.0/16 dockerNet2```
```docker network create --subnet=172.30.0.0/16 dockerNet3```

Rather than include the build commands in the compose file, We will build our images directly using the cli

From inside the etcd folder  ...

``` docker build -t etcd-3.5 . ```

From inside the pgpatroni folder ...

``` docker build -t pg16-patroni . ```

If succesfull, you should be able to see the images in your local rpository

```
REPOSITORY              TAG            IMAGE ID       CREATED             SIZE
pg16-patroni            latest         783231a84c8b   About an hour ago   548MB
etcd-3.5                latest         139a9ba47d03   3 days ago          344MB
```

Once the images are ready, fromthe main folder you can run

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

To keep things simple and easy to follow, 

Container names have the word container appended to them.
Postgres containers are named pg1 through pg6 with a somewhat related exposed port.

All exposed ports start with with 5055 and the pg number at the end. So to access pg4 externally, you would use port 50554. To access pg6, 50556 and so on.

obviously, you can also just 

``` docker exec -t pg4 /bin/bash```






