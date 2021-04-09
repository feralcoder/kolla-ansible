#!/bin/bash
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

destroy_vms () {
  SERVERS=`openstack server list | grep -v '\-\-\-\-\|ID' | awk '{print $2}'`
  for SERVER in $SERVERS; do
    openstack server delete $SERVER
  done
}
destroy_lbs () {
  POOLS=`openstack loadbalancer pool list | grep -iv '\-\-\-\-\|project_id' | awk '{print $2}'`
  for POOL in $POOLS; do
    MEMBERS=`openstack loadbalancer member list $POOL | grep -iv '\-\-\-\-\|project_id' | awk '{print $2}'`
    for MEMBER in $MEMBERS; do
      openstack loadbalancer member delete $POOL $MEMBER
    done
    openstack loadbalancer pool delete $POOL
  done
  LISTENERS=`openstack loadbalancer listener list | grep -iv '\-\-\-\-\|project_id' | awk '{print $2}'`
  for LISTENER in $LISTENERS; do
    openstack loadbalancer listener delete $LISTENER
  done
  LBS=`openstack loadbalancer list | grep -iv '\-\-\-\-\|project_id' | awk '{print $2}'`
  for LB in $LBS; do
    openstack loadbalancer delete $LB
  done
}

destroy_and_rebuild () {
  kolla-ansible -i $UTILITY_DIR/../../files/kolla-inventory-feralstack destroy     --yes-i-really-really-mean-it &&
  $UTILITY_DIR/../07-deploy-kolla.sh && 
  $UTILITY_DIR/../08a-post-deploy-kolla.sh &&
  $UTILITY_DIR/../08b-octavia-setup.sh
  $UTILITY_DIR/../09a-setup-test-envs.sh
}




pull_changes            || fail_exit "pull_changes"
destroy_lbs             || fail_exit "destroy_lbs"
destroy_vms             || fail_exit "destroy_vms"
regenerate_global_conf  || fail_exit "regenerate_global_conf"
destroy_and_rebuild     || fail_exit "destroy_and_rebuild"
