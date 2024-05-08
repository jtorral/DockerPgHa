#!/bin/bash

LOGFILE="${CFG_DIR}/${STANZA_NAME}-restore.log"

rm -f ${CFG_DIR}/restoreme
rm -rf ${DATADIR}/*

cat /dev/null >  $LOGFILE
chown postgres:postgres $LOGFILE

echo -e `date` " - Attempting to run pgbackrest restore with the following command  " >> $LOGFILE
echo -e `date` " - sudo -u postgres pgbackrest --config=${CFG_DIR}/pgbackrest.conf --log-path=${CFG_DIR} --stanza=${STANZA_NAME} --pg1-path=${DATADIR} --log-level-console=info --log-level-file=detail restore " >> $LOGFILE
echo -e >> $LOGFILE
echo -e >> $LOGFILE

sudo -u postgres pgbackrest --config=${CFG_DIR}/pgbackrest.conf --log-path=${CFG_DIR} --stanza=${STANZA_NAME} --pg1-path=${DATADIR} --log-level-console=info --log-level-file=detail restore

echo -e >> $LOGFILE

### -- start patroni
if [ ${BACKGROUND} -eq 1 ]; then
   sudo -u postgres nohup /usr/bin/patroni ${CFG_DIR}/patroni.conf &
   tail -f /dev/null
else
   sudo -u postgres /usr/bin/patroni ${CFG_DIR}/patroni.conf
fi
