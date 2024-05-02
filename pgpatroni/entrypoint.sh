#!/bin/bash

### -- ENV are set in docker-compose

### -- create the default patroni config file if it does not exist yet

if [ ! -f "${CFG_DIR}/patroni.conf" ]; then

echo "
namespace: ${NAMESPACE}
scope: ${SCOPE}
name: ${NODE_NAME}

restapi:
    listen: 0.0.0.0:8008
    connect_address: ${NODE_NAME}:8008

etcd3:
    hosts: ${ETCD_NODES}

bootstrap:
    dcs:
        ttl: 30
        loop_wait: 10
        retry_timeout: 10
        maximum_lag_on_failover: 1048576
        postgresql:
            parameters:
                wal_level: logical
                hot_standby: on
                wal_keep_size: 4096
                max_wal_senders: 10
                max_replication_slots: 10
                wal_log_hints: on
                archive_mode: on
                archive_command: /bin/true
                #archive_command: pgbackrest --stanza=${STANZA_NAME} archive-push \"${DATADIR}/pg_wal/%f\"
                archive_timeout: 1800s
                logging_collector: 'on'
                log_line_prefix: '%m [%r] [%p]: [%l-1] user=%u,db=%d,host=%h '
                log_filename: 'postgresql-%a.log'
                log_filename: 'postgresql-%Y-%m-%d-%a.log'
                log_lock_waits: 'on'
                log_min_duration_statement: 1000
                max_wal_size: 1GB

            #recovery_conf:
                #recovery_target_timeline: latest
                #restore_command: pgbackrest --config=${CFG_DIR}/pgbackrest.conf --stanza=${STANZA_NAME} archive-get %f \"%p\"

            use_pg_rewind: true
            use_slots: true

    # some desired options for 'initdb'
    initdb:
        - encoding: UTF8
        - data-checksums

    pg_hba: # Add following lines to pg_hba.conf after running 'initdb'
        - host replication replicator 127.0.0.1/32 trust
        - host replication replicator 0.0.0.0/0 md5
        - host all all 0.0.0.0/0 md5
        - host all all ::0/0 md5

    # Some optional additional users created after initializing new cluster
    users:
        dude:
            password: dude
            options:
                - createrole
                - createdb
                - superuser


postgresql:
    cluster_name: ${SCOPE}
    listen: 0.0.0.0:5432
    connect_address: ${NODE_NAME}:5432
    data_dir: ${DATADIR}
    bin_dir: ${PG_BIN_DIR}
    pgpass: ${CFG_DIR}/pgpass

    authentication:
        replication:
            username: replicator
            password: replicator
        superuser:
            username: postgres
            password: postgres

    parameters:
        unix_socket_directories: /var/run/postgresql/

    create_replica_methods:
        - pgbackrest
        - basebackup

    pgbackrest:
        command: pgbackrest --config=${CFG_DIR}/pgbackrest.conf --stanza=stanza=${STANZA_NAME} restore --type=delta
        keep_data: True
        no_params: True

    basebackup:
        checkpoint: 'fast'

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false

" > ${CFG_DIR}/patroni.conf

chown postgres:postgres ${CFG_DIR}/patroni.conf

fi



### -- Generate a file to use in case you want to run pgbackrest if its not there yet

if [ ! -f "${CFG_DIR}/patroni_with_pgbackrest.readme" ]; then

echo "

### If you decide to use pgbackrest with this deploy, you must change the patroni configuration in the dcs.
### to do so, run  
###
### patronictl -c ${CFG_DIR}/patroni.conf edit-config 
###
### If you have already made changes to your configuration file in the past, just replace the archive_command line with
###
### archive_command: pgbackrest --stanza=${STANZA_NAME} archive-push "${DATADIR}/pg_wal/%f"
###
### and add
###
###  pgbackrest:
###    command:  pgbackrest --config=${CFG_DIR}/pgbackrest.conf --stanza=${STANZA_NAME} --log-level-file=detail --delta restore
###    keep_data: true
###    no_params: true
###
###  recovery_conf:
###    recovery_target_timeline: latest
###    restore_command: pgbackrest --config=${CFG_DIR}/pgbackrest.conf --stanza=${STANZA_NAME} archive-get %f "%p"
###
### If you have not made changes and are using the default that came with te repo, just copy the info below
### and replace everything with it.
###


loop_wait: 10
maximum_lag_on_failover: 1048576
postgresql:
  parameters:
    archive_command: pgbackrest --stanza=${STANZA_NAME} archive-push "${DATADIR}/pg_wal/%f"
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
  pgbackrest:
    command:  pgbackrest --config=${CFG_DIR}/pgbackrest.conf --stanza=${STANZA_NAME} --log-level-file=detail --delta restore
    keep_data: true
    no_params: true
  recovery_conf:
    recovery_target_timeline: latest
    restore_command: pgbackrest --config=${CFG_DIR}/pgbackrest.conf --stanza=${STANZA_NAME} archive-get %f "%p"
  use_pg_rewind: true
  use_slots: true
retry_timeout: 10
ttl: 30
" > ${CFG_DIR}/patroni_with_pgbackrest.readme


chown postgres:postgres ${CFG_DIR}/patroni_with_pgbackrest.readme

fi



### -- Generate pgbackrest.conf  if it's not there yet

if [ ! -f "${CFG_DIR}/pgbackrest.conf" ]; then

echo "
[global]

repo1-host=${PGBACKREST_SERVER}
repo1-host-user=postgres

process-max=16
log-level-console=detail
log-level-file=debug

[${STANZA_NAME}]

pg1-path=${DATADIR}

" > ${CFG_DIR}/pgbackrest.conf 


#### This sym link part is important ###

mv  /etc/pgbackrest.conf  /etc/pgbackrest.conf.orig
ln -s ${CFG_DIR}/pgbackrest.conf /etc/pgbackrest.conf

# -- end of pgbackrest stuff --

chown postgres:postgres ${CFG_DIR}/pgbackrest.conf

fi


### -- remove ssh prompting to continue and start sshd manually

echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config
/usr/sbin/sshd


### -- if we see a file called restoreme, run tghe restore script

if [ -f "${CFG_DIR}/restoreme" ]; then
        ### -- privs should be taken care of in Docker image. But, making sure
        chown postgres:postgres ${CFG_DIR}/pgbackrestRestore.sh
        chmod 755 ${CFG_DIR}/pgbackrestRestore.sh
        ${CFG_DIR}/pgbackrestRestore.sh
else
        ### -- start patroni
        su -c '/usr/bin/patroni ${CFG_DIR}/patroni.conf' postgres
fi


