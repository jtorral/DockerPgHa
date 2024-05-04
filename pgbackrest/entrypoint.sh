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

" > ${CFG_DIR}/pgbackrest.conf



### Add the hostnames to the config file based on created nodes 
### We look at the environment varibales to determine the node.
### It is set in the maindocker-compose file that kicks off everything

nodeList=$(env | grep -E 'NODE[0-9]+' | sort | awk -F '=' '{print $2}')
counter=1
for nodeName in $nodeList
do
   echo -e "pg${counter}-host=${nodeName}" >> ${CFG_DIR}/pgbackrest.conf
   echo -e "pg${counter}-port=${PGPORT}" >> ${CFG_DIR}/pgbackrest.conf
   echo -e "pg${counter}-path=${DATADIR}" >> ${CFG_DIR}/pgbackrest.conf
   echo -e >> ${CFG_DIR}/pgbackrest.conf
   counter=$(( $counter + 1 ))
done

### This sym link part is important ###

mv /etc/pgbackrest.conf  /etc/pgbackrest.conf.orig
ln -s /pgha/config/pgbackrest.conf /etc/pgbackrest.conf

chown -R postgres:postgres /pgha

# -- remove ssh prompting to continue and start sshd manually

echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config
/usr/sbin/sshd


# -- do ssh stuf above first so you can login without prompts

### Create stanza if it does not exist

stanzaStatus=$(su -c 'pgbackrest --stanza=$STANZA_NAME info' postgres | grep 'missing stanza path' | wc -l)
if [ ${stanzaStatus} -eq 1 ]; then
   ### Lets try a few times while giving container time to start
   for (( x=1; x<=10; x++ ))
   do
      su -c 'pgbackrest --stanza=${STANZA_NAME} stanza-create' postgres
      if [ $? -ne 0 ]; then
         sleep 15
      else
         break
      fi
   done
fi


# -- keep container running for testing
tail -f /dev/null


