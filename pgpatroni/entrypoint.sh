#!/bin/bash

# -- if file does not exist, create the config

if [ -f "${CFG_DIR}/patroni.conf" ]; then
	# patroni config file already there, lets start patroni without creating the file
        #if [ -d "${DATADIR}/log/" ]; then
           #ln -s ${DATADIR}/log/ /tmp/${NODE_NAME}-pg-logs
        #fi
	su -c '/usr/bin/patroni ${CFG_DIR}/patroni.conf' postgres
	exit 0
fi


# -- last thing we do is create the patroni config file and start patroni if hasnt ben done already above

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
        jtorral:
            password: jtorral
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
        #- pgbackrest
        - basebackup

    #pgbackrest:
        #command: pgbackrest --config=${CFG_DIR}/pgbackrest.conf --delta --type=standby --stanza=${STANZA_NAME} restore
        #keep_data: True
        #no_params: True

    basebackup:
        checkpoint: 'fast'

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false

" > ${CFG_DIR}/patroni.conf

chown postgres:postgres ${CFG_DIR}/patroni.conf

#if [ -d "${DATADIR}/log/" ]; then
   #ln -s ${DATADIR}/log/ /tmp/${NODE_NAME}-pg-logs
#fi

su -c '/usr/bin/patroni ${CFG_DIR}/patroni.conf' postgres
