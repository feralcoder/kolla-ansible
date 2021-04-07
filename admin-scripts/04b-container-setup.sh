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

#INSTALL_TYPE=source
# GET INSTALL_TYPE FROM /etc/kolla/globals.yml
get_install_type () {
  INSTALL_TYPE=`grep '^kolla_install_type' /etc/kolla/globals.yml | tail -n 1 | awk '{print $2}' | sed 's/"//g'`
}
get_install_type
[[ $INSTALL_TYPE != "" ]] || { echo "No INSTALL_TYPE discovered!  Define in /etc/kolla/globals.yml or supply as ENV VAR!"; exit 1; }


FERALCODER_SOURCE=~/CODE/feralcoder
KOLLA_ANSIBLE_SOURCE=$FERALCODER_SOURCE/kolla-ansible

KOLLA_PULL_THRU_CACHE=/registry/docker/pullthru-registry/docker/registry/v2/repositories/kolla/
LOCAL_REGISTRY=192.168.127.220:4001
PULL_HOST=kgn




block_dockerio () {
  NON_REGISTRY_HOSTS=`group_logic_remove_host "$ALL_HOSTS" $REGISTRY_HOST`

  ssh_control_run_as_user_these_hosts root "(grep '0.0.0.0.*auth.docker.io.*' /etc/hosts ) && sed -i 's/.*0.0.0.0 auth.docker.io.*/0.0.0.0  auth.docker.io registry-1.docker.io index.docker.io dseasb33srnrn.cloudfront.net production.cloudflare.docker.com/g' /etc/hosts || echo '0.0.0.0  auth.docker.io registry-1.docker.io index.docker.io dseasb33srnrn.cloudfront.net production.cloudflare.docker.com' >> /etc/hosts" "$NON_REGISTRY_HOSTS"
}

use_localized_containers () {
  # Switch back to local (pinned) fetches for deployment
  cp $KOLLA_SETUP_DIR/../files/kolla-globals-localpull.yml /etc/kolla/globals.yml         ||  return 1
  cat $KOLLA_SETUP_DIR/../files/kolla-globals-remainder.yml >> /etc/kolla/globals.yml     ||  return 1
}

use_upstream_containers () {
  # We switch to dockerhub container fetches, to get the latest "victoria" containers
  cp $KOLLA_SETUP_DIR/../files/kolla-globals-dockerpull.yml /etc/kolla/globals.yml         ||  return 1
  cat $KOLLA_SETUP_DIR/../files/kolla-globals-remainder.yml >> /etc/kolla/globals.yml      ||  return 1
}


# Uses kolla-ansible to pull latest containers...
#  This is bad - Docker registries don't handle stampeding herd well.
#  Use update_existing_containers first, then run this
kolla_ansible_pull_containers () {
  kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack pull               || return 1
  use_localized_containers                                                                 || return 1
}

# This is preferable to allowing kolla-ansible to do it:
#  Docker-pullthru-registry doesn't handle the stampeding herd well
#  Better to serialize both clients and pulls
update_existing_upstream_containers () {
  cd $KOLLA_PULL_THRU_CACHE
  for CONTAINER in `ls -d *${INSTALL_TYPE}*`; do
    echo $CONTAINER
    ssh_control_run_as_user root "docker image pull kolla/$CONTAINER:victoria" $PULL_HOST                                                      || return 1
  done 
}

# For all existing kolla containers in registry: Pull the latest from docker.io, retag, and stuff locally
update_and_localize_existing_upstream_containers () {
  cd $KOLLA_PULL_THRU_CACHE
  for CONTAINER in `ls -d *${INSTALL_TYPE}*`; do
    ssh_control_run_as_user root "docker image pull kolla/$CONTAINER:victoria" $PULL_HOST                                                      || return 1
    ssh_control_run_as_user root "docker image tag kolla/$CONTAINER:victoria $LOCAL_REGISTRY/feralcoder/$CONTAINER:latest" $PULL_HOST          || return 1
    ssh_control_run_as_user root "docker image push $LOCAL_REGISTRY/feralcoder/$CONTAINER:latest" $PULL_HOST                                   || return 1
    ssh_control_run_as_user root "docker image tag kolla/$CONTAINER:victoria $LOCAL_REGISTRY/feralcoder/$CONTAINER:upstream-latest" $PULL_HOST || return 1
    ssh_control_run_as_user root "docker image push $LOCAL_REGISTRY/feralcoder/$CONTAINER:upstream-latest" $PULL_HOST                          || return 1
    ssh_control_run_as_user root "docker image tag kolla/$CONTAINER:victoria $LOCAL_REGISTRY/feralcoder/$CONTAINER:$UPSTREAM_TAG" $PULL_HOST   || return 1
    ssh_control_run_as_user root "docker image push $LOCAL_REGISTRY/feralcoder/$CONTAINER:$UPSTREAM_TAG" $PULL_HOST                            || return 1
  done
  # build_and_use_containers also updates TAG in globals.yml: Watch for Race!
  sed -i "s/^openstack_release.*/openstack_release: '$UPSTREAM_TAG'/g" $KOLLA_SETUP_DIR/../files/kolla-globals-localpull.yml                   || return 1
  use_localized_containers                                                                                                                     || return 1
}


checkout_kolla_ansible_on_host () {
  local HOST=$1
  ssh_control_run_as_user cliff "if [[ -d $KOLLA_ANSIBLE_SOURCE ]]; then cd $KOLLA_ANSIBLE_SOURCE; git pull; else cd $FERALCODER_SOURCE && git clone https://feralcoder:\`cat ~/.git_password\`@github.com/feralcoder/kolla-ansible kolla-ansible; fi" $HOST
}


build_and_use_containers () {
#  # Build base image
#  $KOLLA_ANSIBLE_SOURCE/utility/docker-images/build-images.sh                                                                               || return 1

  # Build kolla images, using feralcoder base image
  checkout_kolla_ansible_on_host $PULL_HOST                                                                                                  || return 1
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_SOURCE/admin-scripts/utility/build-containers.sh $NOW $INSTALL_TYPE 2>&1" $PULL_HOST         || return 1
  # localize_latest_containers also updates TAG in globals.yml: Watch for Race!
  sed -i "s/^openstack_release.*/openstack_release: '$LOCAL_TAG'/g" $KOLLA_SETUP_DIR/../files/kolla-globals-localpull.yml                    || return 1
  use_localized_containers                                                                                                                   || return 1
}


democratize_docker () {
  ssh_control_run_as_user_these_hosts root "usermod -a -G docker cliff" "$STACK_HOSTS"                                         || return 1
}






get_install_type                                                                         || fail_exit "get_install_type"
use_localized_containers                                                                 || fail_exit "use_localized_containers"
block_dockerio                                                                           || fail_exit "block_dockerio"

democratize_docker                                                                       || fail_exit "democratize_docker"

#build_and_use_containers                                                                 || fail_exit "build_and_use_containers"

#update_existing_upstream_containers                                                      || fail_exit "update_existing_upstream_containers"
#update_and_localize_existing_upstream_containers                                         || fail_exit "update_and_localize_existing_upstream_containers"


#use_upstream_containers                                                                 || return 1
use_localized_containers                                                                 || fail_exit "use_localized_containers"
kolla_ansible_pull_containers                                                            || fail_exit "pull_latest_containers"

