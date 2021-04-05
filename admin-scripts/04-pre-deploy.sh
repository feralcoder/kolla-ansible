#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )

. $KOLLA_SETUP_DIR/common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"
use_venv kolla-ansible            || fail_exit "use_venv kolla-ansible"

REGISTRY_HOST=dmb
# Bail out if not running on registry host
if [[ $(group_logic_get_short_name `hostname`) != $REGISTRY_HOST ]]; then
  echo "You must run this script on the registry host, which should also be the ansile host."
  exit 1
fi

NOW=`date +%Y%m%d_%H%M`
UPSTREAM_TAG=upstream-$NOW
LOCAL_TAG=feralcoder-$NOW

INSTALL_TYPE=source
# OR GET INSTALL_TYPE FROM /etc/kolla/globals.yml
get_install_type () {
  INSTALL_TYPE=`grep '^kolla_install_type' /etc/kolla/globals.yml | tail -n 1 | awk '{print $2}' | sed 's/"//g'`
}

FERALCODER_SOURCE=~/CODE/feralcoder
KOLLA_ANSIBLE_SOURCE=$FERALCODER_SOURCE/kolla-ansible

KOLLA_PULL_THRU_CACHE=/registry/docker/pullthru-registry/docker/registry/v2/repositories/kolla/
LOCAL_REGISTRY=192.168.127.220:4001
PULL_HOST=kgn




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


use_dockerhub_containers () {
  # We switch to dockerhub container fetches, to get the latest "victoria" containers
  cp $KOLLA_SETUP_DIR/../files/kolla-globals-dockerpull.yml /etc/kolla/globals.yml         ||  return 1
  cat $KOLLA_SETUP_DIR/../files/kolla-globals-remainder.yml >> /etc/kolla/globals.yml      ||  return 1
}


# Uses kolla-ansible to pull latest containers...
pull_latest_containers () {
  use_dockerhub_containers                                                                 || return 1
  kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack pull               || return 1
  use_localized_containers                                                                 || return 1
}


# For all existing kolla containers in registry: Pull the latest from docker.io, retag, and stuff locally
localize_latest_containers () {
  for CONTAINER in `ls -d $KOLLA_PULL_THRU_CACHE/*${INSTALL_TYPE}*`; do
    ssh_control_run_as_user root "docker image pull kolla/$CONTAINER:victoria" $PULL_HOST                                                      || return 1
    ssh_control_run_as_user root "docker image tag kolla/$CONTAINER:victoria $LOCAL_REGISTRY/feralcoder/$CONTAINER:latest" $PULL_HOST          || return 1
    ssh_control_run_as_user root "docker image push $LOCAL_REGISTRY/feralcoder/$CONTAINER:latest" $PULL_HOST                                   || return 1
    ssh_control_run_as_user root "docker image tag kolla/$CONTAINER:victoria $LOCAL_REGISTRY/feralcoder/$CONTAINER:upstream-latest" $PULL_HOST || return 1
    ssh_control_run_as_user root "docker image push $LOCAL_REGISTRY/feralcoder/$CONTAINER:upstream-latest" $PULL_HOST                          || return 1
    ssh_control_run_as_user root "docker image tag kolla/$CONTAINER:victoria $LOCAL_REGISTRY/feralcoder/$CONTAINER:$UPSTREAM_TAG" $PULL_HOST   || return 1
    ssh_control_run_as_user root "docker image push $LOCAL_REGISTRY/feralcoder/$CONTAINER:$UPSTREAM_TAG" $PULL_HOST                            || return 1
  done
  # build_and_use_containers also updates TAG in globals.yml
  sed -i 's/^openstack_release.*/openstack_release: "$UPSTREAM_TAG"/g' $KOLLA_SETUP_DIR/../files/kolla-globals-localpull.yml                   || return 1
  use_localized_containers                                                                                                                     || return 1
}


checkout_kolla_ansible_on_host () {
  local HOST=$1
  ssh_control_run_as_user cliff "if [[ -d $KOLLA_ANSIBLE_SOURCE ]]; then cd $KOLLA_ANSIBLE_SOURCE; git pull; else cd $FERALCODER_SOURCE && git clone https://feralcoder:\`cat ~/.git_password\`@github.com/feralcoder/kolla-ansible kolla-ansible; fi" $HOST
}


build_and_use_containers () {
#  # Build base image
#  $KOLLA_ANSIBLE_SOURCE/utility/docker-images/build-images.sh                                                                 || return 1

  # Build kolla images, using feralcoder base image
  checkout_kolla_ansible_on_host $PULL_HOST                                                                                    || return 1
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_SOURCE/admin-scripts/utility/build-containers.sh $NOW 2>&1" $PULL_HOST         || return 1
  # localize_latest_containers also updates TAG in globals.yml
  sed -i 's/^openstack_release.*/openstack_release: "$LOCAL_TAG"/g' $KOLLA_SETUP_DIR/../files/kolla-globals-localpull.yml      || return 1
  use_localized_containers                                                                                                     || return 1
}


democratize_docker () {
  ssh_control_run_as_user_these_hosts root "usermod -a -G docker cliff" "$STACK_HOSTS"                                         || return 1
}


setup_ssl_certs () {
#  SELF-SIGNED CERTS DON'T WORK IN KOLLA-ANSIBLE AS DOCUMENTED

#  # DO ONCE: Have kolla-ansible generate certs, then stash them into git://feralcoder (encrypted)
#  #  Also place stack's root ca for building into base container image.
#  kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack certificates       || return 1
#  tar -C /etc/kolla -cf $KOLLA_SETUP_DIR/../files/kolla-certificates.tar certificates
#  openssl enc -aes-256-cfb8 --pass file:/home/cliff/.password -md sha256 -in $KOLLA_SETUP_DIR/../files/kolla-certificates.tar -out $KOLLA_SETUP_DIR/../files/kolla-certificates.encrypted
#  # PLACE root CA into base image container.  REBUILD CONTAINERS!
#  cp /etc/kolla/certificates/ca/root.crt $KOLLA_SETUP_DIR/utility/docker-images/centos-feralcoder/stack.crt

  # AFTER REGENERATION: copy /etc/kolla/certificates/ca/root.crt into all containers.
  #   The root.crt will be copied as stack.crt into base container build directory
  #   Containers must then be rebuilt, via build_and_use_containers

  openssl enc --pass file:/home/cliff/.password -d -aes-256-cfb8 -md sha256 -in $KOLLA_SETUP_DIR/../files/kolla-certificates.encrypted -out $KOLLA_SETUP_DIR/../files/kolla-certificates.tar
  tar -C /etc/kolla -xf $KOLLA_SETUP_DIR/../files/kolla-certificates.tar
  ssh_control_sync_as_user_these_hosts root /etc/kolla/certificates/ca/root.crt /etc/pki/ca-trust/source/anchors/stack.crt "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts root update-ca-trust "$ALL_HOSTS"
}




get_install_type                                                                         || fail_exit "get_install_type"

#refetch_api_keys                                                                         || fail_exit "refetch_api_keys"
kolla-genpwd                                                                             || fail_exit "kolla-genpwd"
ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack all -m ping              || fail_exit "ansible ping"
## Use local registry so insecure-registries is set up correctly by bootstrap-servers
use_localized_containers                                                                 || fail_exit "use_localized_containers"
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack bootstrap-servers  || fail_exit "kolla-ansible bootstrap-servers"
democratize_docker                                                                       || fail_exit "democratize_docker"

#setup_ssl_certs                                                                          || fail_exit "setup_ssl_certs"
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack prechecks          || fail_exit "kolla-ansible prechecks"

## BUILD SOURCE CONTAINERS.  This must be done if self-signed certs are used, after certs are generated.
#build_and_use_containers                                                                 || fail_exit "build_and_use_containers"
#
## PULL BINARY CONTAINERS FROM DOCKERIO
#pull_latest_containers                                                                   || fail_exit "pull_latest_containers"
#localize_latest_containers                                                               || fail_exit "localize_latest_containers"
