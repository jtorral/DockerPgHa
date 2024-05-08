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
                #archive_command: /bin/true
                archive_command: pgbackrest --config=${CFG_DIR}/pgbackrest.conf --stanza=${STANZA_NAME} archive-push \"${DATADIR}/pg_wal/%f\"
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
                #restore_command: pgbackrest --config=${CFG_DIR}/pgbackrest.conf --stanza=${STANZA_NAME} archive-get %f "%p"

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

    recovery_conf:
        recovery_target_timeline: latest
        restore_command: pgbackrest --config=${CFG_DIR}/pgbackrest.conf --stanza=${STANZA_NAME} archive-get %f \"%p\"

    basebackup:
        checkpoint: 'fast'
        wal-method: 'stream'

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false

" > ${CFG_DIR}/patroni.conf

chown postgres:postgres ${CFG_DIR}/patroni.conf

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
        if [ ${BACKGROUND} -eq 1 ]; then 
           su -c 'nohup /usr/bin/patroni ${CFG_DIR}/patroni.conf &' postgres
           tail -f /dev/null
        else 
           su -c '/usr/bin/patroni ${CFG_DIR}/patroni.conf ' postgres
        fi
fi


