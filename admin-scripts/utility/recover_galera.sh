#!/bin/bash
UTILITY_SOURCE="${BASH_SOURCE[0]}"
UTILITY_DIR=$( realpath `dirname $UTILITY_SOURCE` )

. $UTILITY_DIR/../common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"
use_venv kolla-ansible            || fail_exit "use_venv kolla-ansible"

KOLLA_CHECKOUT=/home/cliff/CODE/feralcoder/kolla-ansible
NOW=`date +%Y%m%d-%H%M%S`
LOG_DIR=~/kolla-ansible-logs/


ansible -i ~/CODE/feralcoder/kolla-ansible/files/kolla-inventory-feralstack   control   -m command -a "docker stop mariadb"
kolla-ansible -i $KOLLA_CHECKOUT/files/kolla-inventory-feralstack mariadb_recovery >$LOG_DIR/recover_galera_$NOW.log 2>&1




## CHECK GALERA STATE
#docker exec -it  mariadb cat /var/lib/mysql/grastate.dat
#docker stop mariadb
#
#
## FIND MASTER NODE / RECOVERY NODE
## ON HOST: vi /etc/kolla/mariadb/galera.cnf
## REPLACE: 
##wsrep_cluster_address = gcomm://172.19.4.210:4567,172.19.4.212:4567,172.19.4.216:4567
#wsrep_cluster_address="gcomm://"
#
## IN CONTAINER: vi /etc/my.cnf, ADD (start with 1, increase to 6 until success....?)
#innodb_recovery_force=1

