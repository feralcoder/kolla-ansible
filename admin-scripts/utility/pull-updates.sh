#!/bin/bash
UTILITY_SOURCE="${BASH_SOURCE[0]}"
UTILITY_DIR=$( realpath `dirname $UTILITY_SOURCE` )
# RUN ON ANSIBLE CONTROLLER

. $UTILITY_DIR/../common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"
use_venv kolla-ansible            || fail_exit "use_venv kolla-ansible"

KOLLA_UTIL_SOURCE="${BASH_SOURCE[0]}"
KOLLA_UTIL_DIR=$( realpath `dirname $KOLLA_UTIL_SOURCE` )
KOLLA_SETUP_DIR=$KOLLA_UTIL_DIR/..
KOLLA_PULL_THRU_CACHE=/registry/docker/pullthru-registry/docker/registry/v2/repositories/kolla/
LOCAL_REGISTRY=192.168.127.220:4001
PULL_HOST=kgn
#TAG=feralcoder-20210324
TAG=feralcoder-`date  +%Y%m%d`




refetch_api_keys () {
  echo; echo "REFETCHING HOST KEYS FOR API NETWORK EVERYWHERE"
  for HOST in $ALL_HOSTS; do
    ssh_control_run_as_user cliff "ssh_control_refetch_hostkey_these_hosts \"$STACK_HOSTS_API_NET\"" $HOST 2>/dev/null  || fail_exit "ssh_control_refetch_hostkey_these_hosts"
  done
}

use_localized_containers () {
  # Switch back to local (pinned) fetches for deployment
  cp $KOLLA_SETUP_DIR/../files/kolla-globals-localpull.yml /etc/kolla/globals.yml         ||  return 1
  cat $KOLLA_SETUP_DIR/../files/kolla-globals-remainder.yml >> /etc/kolla/globals.yml     ||  return 1
  [[ ! -f /etc/kolla/globals-octavia.yml ]] || cat /etc/kolla/globals-octavia.yml >> /etc/kolla/globals.yml     ||  return 1
}

use_dockerhub_containers () {
  # We switch to dockerhub container fetches, to get the latest "victoria" containers
  cp $KOLLA_SETUP_DIR/../files/kolla-globals-dockerpull.yml /etc/kolla/globals.yml         ||  return 1
  cat $KOLLA_SETUP_DIR/../files/kolla-globals-remainder.yml >> /etc/kolla/globals.yml      ||  return 1
  [[ ! -f /etc/kolla/globals-octavia.yml ]] || cat /etc/kolla/globals-octavia.yml >> /etc/kolla/globals.yml     ||  return 1
}

localize_latest_containers () {
  for CONTAINER in `ls $KOLLA_PULL_THRU_CACHE`; do
    ssh_control_run_as_user root "docker image pull kolla/$CONTAINER:victoria" $PULL_HOST
    ssh_control_run_as_user root "docker image tag kolla/$CONTAINER:victoria $LOCAL_REGISTRY/feralcoder/$CONTAINER:$TAG" $PULL_HOST
    ssh_control_run_as_user root "docker image push $LOCAL_REGISTRY/feralcoder/$CONTAINER:$TAG" $PULL_HOST
  done
}


use_localized_containers                                                                 || fail_exit "use_localized_containers"
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack bootstrap-servers  || fail_exit "kolla-ansible bootstrap-servers"
# Set globals.yml to dockerhub to inform package fetch names (kolla/*:victoria)
# But do not re-bootstrap!
use_dockerhub_containers                                                                 || fail_exit "use_dockerhub_containers"
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack pull               || fail_exit "kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack pull"
use_localized_containers                                                                 || fail_exit "use_localized_containers"
localize_latest_containers                                                               || fail_exit "localize_latest_containers"
