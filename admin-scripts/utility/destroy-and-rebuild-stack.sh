#!/bin/bash -e
UTILITY_SOURCE="${BASH_SOURCE[0]}"
UTILITY_DIR=$( realpath `dirname $UTILITY_SOURCE` )
# RUN ON ANSIBLE CONTROLLER

. $UTILITY_DIR/../common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"
use_venv kolla-ansible            || fail_exit "use_venv kolla-ansible"

. /etc/kolla/admin-openrc.sh


pull_changes () {
  cd $UTILITY_DIR
  NO_CHANGES=`git stash push | grep 'No local changes'`
  git pull
  if [[ $NO_CHANGES == "" ]]; then git stash pop; fi
}

regenerate_global_conf () {
  if ( grep "CONTAINERS FROM FERALCODER"  /etc/kolla/globals.yml ); then
    cat $UTILITY_DIR/../../files/kolla-globals-localpull.yml $UTILITY_DIR/../../files/kolla-globals-remainder.yml > /etc/kolla/globals.yml
  elif ( grep "CONTAINERS FROM DOCKER"  /etc/kolla/globals.yml ); then
    cat $UTILITY_DIR/../../files/kolla-globals-dockerpull.yml $UTILITY_DIR/../../files/kolla-globals-remainder.yml > /etc/kolla/globals.yml
  fi
}

run_octavia_sql () {
  ssh_control_sync_as_user root $SQL_FILE $SQL_FILE $CONTROLLER
  ssh_control_run_as_user root "docker cp $SQL_FILE mariadb:$SQL_FILE" $CONTROLLER
  ssh_control_run_as_user root "docker exec mariadb $CMD_FILE" $CONTROLLER
}

setup_octavia_sql () {
  for CONTROLLER in $CONTROL_HOSTS; do
    break
  done
  OCT_DB_USER=octavia
  OCT_PASS_FILE=/tmp/.oct_db_pass
  grep octavia_database_password /etc/kolla/passwords.yml | awk '{print $2}' > $OCT_PASS_FILE
  ssh_control_sync_as_user root $OCT_PASS_FILE $OCT_PASS_FILE $CONTROLLER
  ssh_control_run_as_user root "docker cp $OCT_PASS_FILE mariadb:$OCT_PASS_FILE" $CONTROLLER
  SQL_FILE=/tmp/cmd.sql
  CMD_FILE=/tmp/cmd.sh
}


set_all_lbs_to_active_before_delete () {
  setup_octavia_sql
  echo '#!/bin/bash' > $CMD_FILE
  echo "mysql octavia -u $OCT_DB_USER --password=`cat $OCT_PASS_FILE` < $SQL_FILE" >> $CMD_FILE
  chmod 755 $CMD_FILE
  ssh_control_sync_as_user root $CMD_FILE $CMD_FILE $CONTROLLER
  ssh_control_run_as_user root "docker cp $CMD_FILE mariadb:$CMD_FILE" $CONTROLLER

  LOADBALANCERS=`openstack loadbalancer list | grep -v '\-\-\-\| name ' | awk '{print $2}'`
  for LOADBALANCER in $LOADBALANCERS; do
    echo "update load_balancer set provisioning_status = 'ACTIVE' where id = '$LOADBALANCER'" > $SQL_FILE
    run_octavia_sql
  done
}

set_all_pools_to_active_before_delete () {
  setup_octavia_sql
  echo '#!/bin/bash' > $CMD_FILE
  echo "mysql octavia -u $OCT_DB_USER --password=`cat $OCT_PASS_FILE` < $SQL_FILE" >> $CMD_FILE
  chmod 755 $CMD_FILE
  ssh_control_sync_as_user root $CMD_FILE $CMD_FILE $CONTROLLER
  ssh_control_run_as_user root "docker cp $CMD_FILE mariadb:$CMD_FILE" $CONTROLLER

  POOLS=`openstack loadbalancer pool list | grep -v '\-\-\-\| name ' | awk '{print $2}'`
  for POOL in $POOLS; do
    echo "update pool set provisioning_status = 'ACTIVE' where id = '$POOL'" > $SQL_FILE
    run_octavia_sql
  done
}

set_all_listeners_to_active_before_delete () {
  setup_octavia_sql
  echo '#!/bin/bash' > $CMD_FILE
  echo "mysql octavia -u $OCT_DB_USER --password=`cat $OCT_PASS_FILE` < $SQL_FILE" >> $CMD_FILE
  chmod 755 $CMD_FILE
  ssh_control_sync_as_user root $CMD_FILE $CMD_FILE $CONTROLLER
  ssh_control_run_as_user root "docker cp $CMD_FILE mariadb:$CMD_FILE" $CONTROLLER

  LISTENERS=`openstack loadbalancer listener list | grep -v '\-\-\-\| name ' | awk '{print $2}'`
  for LISTENER in $LISTENERS; do
    echo "update listener set provisioning_status = 'ACTIVE' where id = '$LISTENER'" > $SQL_FILE
    run_octavia_sql
  done
}


destroy_heat_stacks () {
  STACKS=`openstack stack list | grep -v '\-\-\-\|ID' | awk '{print $2}'` || return 1
  for STACK in $STACKS; do
    openstack stack delete -y --wait $STACK || return 1
  done
}
destroy_vms () {
  SERVERS=`openstack server list | grep -v '\-\-\-\-\|ID' | awk '{print $2}'`
  for SERVER in $SERVERS; do
    openstack server delete $SERVER
  done
}
#destroy_lbs () {
#  set_all_pools_to_active_before_delete
#  POOLS=`openstack loadbalancer pool list | grep -iv '\-\-\-\-\|project_id' | awk '{print $2}'`
#  for POOL in $POOLS; do
#    MEMBERS=`openstack loadbalancer member list $POOL | grep -iv '\-\-\-\-\|project_id' | awk '{print $2}'`
#    for MEMBER in $MEMBERS; do
#      openstack loadbalancer member delete $POOL $MEMBER
#    done
#    openstack loadbalancer pool delete $POOL
#  done
#
#  set_all_listeners_to_active_before_delete
#  LISTENERS=`openstack loadbalancer listener list | grep -iv '\-\-\-\-\|project_id' | awk '{print $2}'`
#  for LISTENER in $LISTENERS; do
#    openstack loadbalancer listener delete $LISTENER
#  done
#
#  set_all_lbs_to_active_before_delete
#  LBS=`openstack loadbalancer list | grep -iv '\-\-\-\-\|project_id' | awk '{print $2}'`
#  for LB in $LBS; do
#    openstack loadbalancer delete $LB --cascade
#  done
#}
destroy_lbs () {
  LBS=`openstack loadbalancer list | grep -iv '\-\-\-\-\|project_id' | awk '{print $2}'`
  for LB in $LBS; do
    openstack loadbalancer delete $LB --cascade
  done
}
destroy_clusters () {
  CLUSTERS=`openstack coe cluster list | grep -iv '\-\-\-\-\| uuid ' | awk '{print $2}'`
  for CLUSTER in $CLUSTERS; do
    openstack coe cluster delete $CLUSTER
  done
}

destroy_and_rebuild () {
  kolla-ansible -i $UTILITY_DIR/../../files/kolla-inventory-feralstack destroy     --yes-i-really-really-mean-it &&
  $UTILITY_DIR/../04a-pre-deploy.sh &&
  $UTILITY_DIR/../06-post-deploy-ceph.sh &&
  $UTILITY_DIR/../07-deploy-kolla.sh && 
  $UTILITY_DIR/../08a-post-deploy-kolla.sh &&
  $UTILITY_DIR/../08a-pubnet1-setup.sh &&
  $UTILITY_DIR/../08b-octavia-setup.sh &&
  $UTILITY_DIR/../08c-config-fixes.sh &&
  $UTILITY_DIR/../09a-setup-feralstack.sh
}




pull_changes            || fail_exit "pull_changes"
destroy_lbs             || fail_exit "destroy_lbs"
destroy_heat_stacks     || fail_exit "destroy_heat_stacks"
destroy_vms             || fail_exit "destroy_vms"
destroy_clusters        || fail_exit "destroy_clusters"
regenerate_global_conf  || fail_exit "regenerate_global_conf"
destroy_and_rebuild     || fail_exit "destroy_and_rebuild"
