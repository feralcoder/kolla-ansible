#!/bin/bash

# RUN ON ANSIBLE CONTROLLER

# BAIL OUT IF USER SOURCES SCRIPT, INSTEAD OF RUNNING IT
if [ ! "${BASH_SOURCE[0]}" -ef "$0" ]; then
  echo "Do not source this script (exits will bail you...)."
  echo "Run it instead"
  return 1
fi

. ~/CODE/venvs/kolla-ansible/bin/activate                                               || fail_exit "venv activate"
. ~/CODE/feralcoder/host_control/control_scripts.sh

KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )
KOLLA_PULL_THRU_CACHE=/registry/docker/pullthru-registry/docker/registry/v2/repositories/kolla/
LOCAL_REGISTRY=192.168.127.220:4001
PULL_HOST=kgn
TAG=feralcoder-`date  +%Y%m%d`


fail_exit () {
  echo; echo "INSTALLATION FAILED AT STEP: $1"
  echo "Check the logs and try again.  Or just give up.  I don't care."
  exit 1
}


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
}

prefetch_latest_containers () {
  # We switch to dockerhub container fetches, to get the latest "victoria" containers
  cp $KOLLA_SETUP_DIR/../files/kolla-globals-dockerpull.yml /etc/kolla/globals.yml         ||  return 1
  cat $KOLLA_SETUP_DIR/../files/kolla-globals-remainder.yml >> /etc/kolla/globals.yml      ||  return 1
  kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack pull               ||  return 1
}

localize_latest_containers () {
  for CONTAINER in `ls $KOLLA_PULL_THRU_CACHE`; do
    ssh_control_run_as_user root "docker image pull kolla/$CONTAINER:victoria" $PULL_HOST
    ssh_control_run_as_user root "docker image tag kolla/$CONTAINER:victoria $LOCAL_REGISTRY/feralcoder/$CONTAINER:$TAG" $PULL_HOST
    ssh_control_run_as_user root "docker image push $LOCAL_REGISTRY/feralcoder/$CONTAINER:$TAG" $PULL_HOST
  done
}


refetch_api_keys                                                                         || fail_exit "refetch_api_keys"
kolla-genpwd                                                                             || fail_exit "kolla-genpwd"
ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack all -m ping              || fail_exit "ansible ping"
# Use local registry so insecure-registries is set up correctly by bootstrap-servers
use_localized_containers                                                                 || fail_exit "use_localized_containers"
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack bootstrap-servers  || fail_exit "kolla-ansible bootstrap-servers"
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack prechecks          || fail_exit "kolla-ansible prechecks"
# This will point globals.yml at dockerhub, until pull completes
prefetch_latest_containers                                                               || fail_exit "prefetch_latest_containers"
localize_latest_containers                                                               || fail_exit "localize_latest_containers"
# Use local registry so we use pinned versions for deployments
use_localized_containers                                                                 || fail_exit "use_localized_containers"
