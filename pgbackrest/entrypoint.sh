#!/bin/bash

### environment variables below are defined in the docker-compose file

echo "
[global]

repo1-path=${REPO_PATH}
repo1-retention-archive-type=full
repo1-retention-full=2

process-max=12
log-level-console=detail
log-level-file=detail
start-fast=y
delta=y
backup-standby=y

[${STANZA_NAME}]

pg1-host=${NODE1}
pg1-port=${PGPORT}
pg1-path=${DATADIR}

pg2-host=${NODE2}
pg2-port=${PGPORT}
pg2-path=${DATADIR}

pg3-host=${NODE3}
pg3-port=${PGPORT}
pg3-path=${DATADIR}

pg4-host=${NODE4}
pg4-port=${PGPORT}
pg4-path=${DATADIR}

pg5-host=${NODE5}
pg5-port=${PGPORT}
pg5-path=${DATADIR}

pg6-host=${NODE6}
pg6-port=${PGPORT}
pg6-path=${DATADIR}

" > ${CFG_DIR}/pgbackrest.conf

### This sym link part is important ###

mv /etc/pgbackrest.conf  /etc/pgbackrest.conf.orig
ln -s /pgha/config/pgbackrest.conf /etc/pgbackrest.conf

chown -R postgres:postgres /pgha

# -- remove ssh prompting to continue and start sshd manually

echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config
/usr/sbin/sshd

# -- keep container running for testing
tail -f /dev/null


