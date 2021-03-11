#!/bin/bash
CEPH_SETUP_SOURCE="${BASH_SOURCE[0]}"
CEPH_SETUP_DIR=$( dirname $CEPH_SETUP_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh


# THIS SCRIPT IS MEANT TO RUN AFTER A KOLLA-ANSIBLE SCRIPT
#  Ansible should already be installed on this host, the ansible controller
VERSION=4.0 # Nautilus



new_venv () {
  mkdir -p ~/CODE/venvs/ceph-ansible
  python3 -m venv ~/CODE/venvs/ceph-ansible
}

use_venv () {
  source ~/CODE/venvs/ceph-ansible/bin/activate
}

install_ceph-ansible_for_dev () {
  echo; echo "INSTALLING CEPH-ANSIBLE"
  cd ~/CODE/feralcoder/
  git clone https://github.com/ceph/ceph-ansible.git
  cd ceph-ansible
  git checkout stable-$VERSION
}





new_venv
use_venv
install_ceph-ansible_for_dev


#my kolla storage_interface will be my monitor_interface
#my kolla cluster_interface will be my cluster_network
#my kolla kolla_external_vip_interface will be my radosgw_interface
