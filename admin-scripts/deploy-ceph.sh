#!/bin/bash
CEPH_SETUP_SOURCE="${BASH_SOURCE[0]}"
CEPH_SETUP_DIR=$( realpath `dirname $CEPH_SETUP_SOURCE` )
# CEPH_SETUP_DIR=~/CODE/feralcoder/kolla-ansible/admin-scripts

CODE_DIR=~/CODE
CEPH_CODE_DIR=$CODE_DIR/ceph
CEPH_CHECKOUT_DIR=$CEPH_CODE_DIR/ceph-ansible

. ~/CODE/feralcoder/host_control/control_scripts.sh


# THIS SCRIPT IS MEANT TO RUN AFTER A KOLLA-ANSIBLE SCRIPT
#  Ansible should already be installed on this host, the ansible controller
VERSION=4.0 # Nautilus


fail_exit () {
  echo; echo "INSTALLATION FAILED AT STEP: $1"
  echo "Check the logs and try again.  Or just give up.  I don't care."
  exit 1
}


new_venv () {
  mkdir -p ~/CODE/venvs/ceph-ansible
  python3 -m venv ~/CODE/venvs/ceph-ansible || return 1
}

use_venv () {
  source ~/CODE/venvs/ceph-ansible/bin/activate || return 1
}

checkout_ceph-ansible_for_dev () {
  echo; echo "INSTALLING CEPH-ANSIBLE"
  mkdir -p $CEPH_CODE_DIR >/dev/null 2>&1
  cd $CEPH_CODE_DIR || return 1
  git clone https://github.com/ceph/ceph-ansible.git
  cd $CEPH_CHECKOUT_DIR || return 1
  git checkout stable-$VERSION
}

install_prereqs () {
  new_venv || return 1
  use_venv || return 1
  pip install -U pip || return 1
  pip install -r $CEPH_CHECKOUT_DIR/requirements.txt || return 1
}



place_ceph_files () {
  # These are pure configuration, no need to back up targets
  cp $CEPH_SETUP_DIR/../files/ceph-osds.yml $CEPH_CHECKOUT_DIR/group_vars/osds.yml &&
  cp $CEPH_SETUP_DIR/../files/ceph-all.yml $CEPH_CHECKOUT_DIR/group_vars/all.yml &&
  cp $CEPH_SETUP_DIR/../files/ceph-site.yml $CEPH_CHECKOUT_DIR/site.yml &&
  cp $CEPH_SETUP_DIR/../files/ceph-mons.yml $CEPH_CHECKOUT_DIR/group_vars/mons.yml &&
  cp $CEPH_SETUP_DIR/../files/ceph-site-docker.yml $CEPH_CHECKOUT_DIR/site-docker.yml &&
  cp $CEPH_SETUP_DIR/../files/ceph-hosts $CEPH_CHECKOUT_DIR/hosts || return 1

  # These are code, corrected for bugs, need to back up.
  # Compare in the future for code drift.  Improve: edit instead of replace.
  XXX=$CEPH_CHECKOUT_DIR/roles/ceph-osd/tasks/main.yml
  [[ -f $XXX.orig ]] || cp $XXX $XXX.orig || return 1
  XXX=$CEPH_CHECKOUT_DIR/roles/ceph-facts/tasks/container_binary.yml
  [[ -f $XXX.orig ]] || cp $XXX $XXX.orig || return 1
  XXX=$CEPH_CHECKOUT_DIR/roles/ceph-container-engine/tasks/pre_requisites/prerequisites.yml
  [[ -f $XXX.orig ]] || cp $XXX $XXX.orig || return 1
  XXX=$CEPH_CHECKOUT_DIR/infrastructure-playbooks/purge-docker-cluster.yml
  [[ -f $XXX.orig ]] || cp $XXX $XXX.orig || return 1
  XXX=$CEPH_CHECKOUT_DIR/roles/ceph-dashboard/tasks/configure_dashboard.yml
  [[ -f $XXX.orig ]] || cp $XXX $XXX.orig || return 1

  cp $CEPH_SETUP_DIR/../files/ceph-main.yml $CEPH_CHECKOUT_DIR/roles/ceph-osd/tasks/main.yml &&
  cp $CEPH_SETUP_DIR/../files/ceph-container_binary.yml $CEPH_CHECKOUT_DIR/roles/ceph-facts/tasks/container_binary.yml &&
  cp $CEPH_SETUP_DIR/../files/ceph-docker-prerequisites.yml $CEPH_CHECKOUT_DIR/roles/ceph-container-engine/tasks/pre_requisites/prerequisites.yml &&
  cp $CEPH_SETUP_DIR/../files/ceph-purge-docker-cluster.yml $CEPH_CHECKOUT_DIR/infrastructure-playbooks/purge-docker-cluster.yml &&
  cp $CEPH_SETUP_DIR/../files/ceph-configure_dashboard.yml $CEPH_CHECKOUT_DIR/roles/ceph-dashboard/tasks/configure_dashboard.yml || return 1
}




checkout_ceph-ansible_for_dev || fail_exit "checkout_ceph-ansible_for_dev"
install_prereqs || fail_exit "install_prereqs"
place_ceph_files || fail_exit "place_ceph_files"

# export ANSIBLE_DEBUG=true
# export ANSIBLE_VERBOSITY=4
ansible-playbook $CEPH_CHECKOUT_DIR/site-docker.yml -i $CEPH_CHECKOUT_DIR/hosts -e container_package_name=docker-ce || fail_exit "ansible-playbook"
