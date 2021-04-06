#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )

. $KOLLA_SETUP_DIR/common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"
use_venv kolla-ansible            || fail_exit "use_venv kolla-ansible"

ANSIBLE_CONTROLLER=dmb
BUILD_HOST=kgn

create_amphora () {
  ssh_control_sync_as_user cliff $KOLLA_SETUP_DIR/utility/build-amphora.sh /home/cliff/build-amphora.sh $BUILD_HOST
  ssh_control_run_as_user cliff /home/cliff/build-amphora.sh $BUILD_HOST

#  THE UBUNTU DOCKER WAY DOESN'T WORK
#  mkdir ~/amphora_cache
#  cp $KOLLA_SETUP_DIR/../files/octavia-amphora-dockerfile ~/amphora_cache/Dockerfile
#  (cd ~/amphora_cache ; docker build -t os .)
#  docker run -it -v ~/amphora_cache:/lab --privileged os
}


#create_amphora
ssh_control_run_as_user cliff ". ~/CODE/venvs/kolla-ansible/bin/activate && . /etc/kolla/admin-openrc.sh && openstack image create --container-format bare --disk-format qcow2 --public --file /registry/images/amphora-x64-centos-haproxy.qcow2 --min-disk 2 --min-ram 1024 --tag amphora amphora --project service" $ANSIBLE_CONTROLLER
