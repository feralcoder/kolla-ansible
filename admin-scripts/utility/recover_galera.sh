#!/bin/bash

# CHECK GALERA STATE
docker exec -it  mariadb cat /var/lib/mysql/grastate.dat
docker stop mariadb


# FIND MASTER NODE / RECOVERY NODE
# ON HOST: vi /etc/kolla/mariadb/galera.cnf
# REPLACE: 
#wsrep_cluster_address = gcomm://172.17.0.210:4567,172.17.0.212:4567,172.17.0.216:4567
wsrep_cluster_address="gcomm://"

# IN CONTAINER: vi /etc/my.cnf, ADD (start with 1, increase to 6 until success....?)
innodb_recovery_force=1

