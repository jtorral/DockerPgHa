FROM ubuntu:22.04

RUN echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker
RUN echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker

RUN DEBIAN_FRONTEND=noninteractive \
  apt-get update \
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


RUN echo | /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
RUN DEBIAN_FRONTEND=noninteractive apt install -y postgresql-16 

RUN DEBIAN_FRONTEND=noninteractive apt install -y patroni 
RUN DEBIAN_FRONTEND=noninteractive apt install -y pgbackrest 

RUN DEBIAN_FRONTEND=noninteractive rm -rf /var/lib/apt/lists/*

# Clean out postgres dir
RUN rm -rf /var/lib/postgresql/16/main/*

RUN mkdir -p /pgha/config
RUN chown -R postgres:postgres /pgha

RUN mkdir -p /pgdata
RUN chown -R postgres:postgres /pgdata
RUN chmod 0700 /pgdata

RUN mkdir /var/lib/postgresql/.ssh
RUN chown -R postgres:postgres /var/lib/postgresql/.ssh
RUN chmod 700 /var/lib/postgresql/.ssh

COPY id_rsa.pub /var/lib/postgresql/.ssh/
COPY id_rsa /var/lib/postgresql/.ssh/
COPY authorized_keys /var/lib/postgresql/.ssh/

RUN chown -R postgres:postgres /var/lib/postgresql/.ssh

RUN chmod 600 /var/lib/postgresql/.ssh/id_rsa
RUN chmod 644 /var/lib/postgresql/.ssh/id_rsa.pub
RUN chmod 644 /var/lib/postgresql/.ssh/authorized_keys

RUN mkdir /run/sshd

COPY entrypoint.sh /
RUN chmod +x entrypoint.sh 

COPY pgbackrestRestore.sh /pgha/config/
RUN chmod +x /pgha/config/pgbackrestRestore.sh

COPY restoremeOnStartup /pgha/config/
RUN chmod +x /pgha/config/restoremeOnStartup

RUN chown -R postgres:postgres /pgha


EXPOSE 5432
