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
LOCAL_TAG=feralcoder-$NOW

#INSTALL_TYPE=source
# GET INSTALL_TYPE FROM /etc/kolla/globals.yml
get_install_type () {
  INSTALL_TYPE=`grep '^kolla_install_type' /etc/kolla/globals.yml | tail -n 1 | awk '{print $2}' | sed 's/"//g'`
}
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

checkout_kolla_ansible_on_host () {
  local HOST=$1
  ssh_control_run_as_user cliff "if [[ -d $KOLLA_ANSIBLE_SOURCE ]]; then cd $KOLLA_ANSIBLE_SOURCE; git pull; else cd $FERALCODER_SOURCE && git clone https://feralcoder:\`cat ~/.git_password\`@github.com/feralcoder/kolla-ansible kolla-ansible; fi" $HOST
}

build_containers () {
#  # Build base image
#  $KOLLA_ANSIBLE_SOURCE/utility/docker-images/build-images.sh                                                                 || return 1

  # Build kolla images, using feralcoder base image
  checkout_kolla_ansible_on_host $PULL_HOST                                                                                    || return 1
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_SOURCE/admin-scripts/utility/build-containers.sh $NOW 2>&1" $PULL_HOST         || return 1
}

use_built_containers () {
  sed -i "s/^openstack_release.*/openstack_release: '$LOCAL_TAG'/g" $KOLLA_SETUP_DIR/../files/kolla-globals-localpull.yml      || return 1
  use_localized_containers                                                                                                     || return 1
}

democratize_docker () {
  ssh_control_run_as_user_these_hosts root "usermod -a -G docker cliff" "$STACK_HOSTS"                                         || return 1
}



get_install_type                                                                         || fail_exit "get_install_type"
use_localized_containers                                                                 || fail_exit "use_localized_containers"
democratize_docker                                                                       || fail_exit "democratize_docker"

build_containers                                                                         || fail_exit "build_containers"
#use_built_version                                                                        || fail_exit "use_built_version"
