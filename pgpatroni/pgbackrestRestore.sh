#!/bin/bash

LOGFILE="${CFG_DIR}/${STANZA_NAME}-restore.log"

rm -f ${CFG_DIR}/restoreme
rm -rf ${DATADIR}/*

cat /dev/null >  $LOGFILE
chown postgres:postgres $LOGFILE

echo -e `date` " - Attempting to run pgbackrest restore with the following command  " >> $LOGFILE
echo -e `date` " - su -c \"pgbackrest --config=${CFG_DIR}/pgbackrest.conf --log-path=${CFG_DIR} --stanza=${STANZA_NAME} --pg1-path=/pgdata --log-level-console=info --log-level-file=detail restore\" postgres " >> $LOGFILE
echo -e >> $LOGFILE
echo -e >> $LOGFILE

su -c 'pgbackrest --config=${CFG_DIR}/pgbackrest.conf --log-path=${CFG_DIR} --stanza=${STANZA_NAME} --pg1-path=/pgdata --log-level-console=info --log-level-file=detail restore' postgres

echo -e >> $LOGFILE

su -c '/usr/bin/patroni ${CFG_DIR}/patroni.conf' postgres
