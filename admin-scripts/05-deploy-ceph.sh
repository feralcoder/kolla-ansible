#!/bin/bash
CEPH_SETUP_SOURCE="${BASH_SOURCE[0]}"
CEPH_SETUP_DIR=$( realpath `dirname $CEPH_SETUP_SOURCE` )
CEPH_FILE_DIR=$CEPH_SETUP_DIR/../files

. $CEPH_SETUP_DIR/common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"

CODE_DIR=~/CODE
CEPH_CODE_DIR=$CODE_DIR/ceph
CEPH_CHECKOUT_DIR=$CEPH_CODE_DIR/ceph-ansible

# SYNC THIS VERSION WITH ../files/ceph-all.yml: ceph_docker_image_tag
CEPH_DOCKER_VERSION=master-86da1a4-nautilus-centos-7
#CEPH_DOCKER_VERSION=latest-nautilus
#CEPH_DOCKER_VERSION=latest-octopus



# THIS SCRIPT IS MEANT TO RUN AFTER A KOLLA-ANSIBLE SCRIPT
#  Ansible should already be installed on this host, the ansible controller
VERSION=4.0 # Nautilus
#VERSION=5.0 # Octopus

adjust_firewall () {
  echo; echo "DISABLING FIREWALL"
  ssh_control_run_as_user_these_hosts root "systemctl disable firewalld" "$STACK_HOSTS"                    || return 1
  ssh_control_run_as_user_these_hosts root "systemctl stop firewalld" "$STACK_HOSTS"                       || return 1
#  ssh_control_run_as_user_these_hosts root "firewall-cmd --zone=public --add-port=4567/tcp" "$CONTROL_HOSTS"                    || return 1
#  ssh_control_run_as_user_these_hosts root "firewall-cmd --permanent --zone=public --add-port=4567/tcp" "$CONTROL_HOSTS"        || return 1
}




checkout_ceph-ansible_for_dev () {
  echo; echo "INSTALLING CEPH-ANSIBLE"
  mkdir -p $CEPH_CODE_DIR >/dev/null 2>&1
  cd $CEPH_CODE_DIR || return 1
  if [[ -d $CEPH_CHECKOUT_DIR ]]; then
#    cd $CEPH_CHECKOUT_DIR && git stash && git pull && git stash apply
    echo; echo "$CEPH_CHECKOUT_DIR already exists, not cloning."
    echo "Manual update recommended!"
    echo
  else
    git clone https://github.com/ceph/ceph-ansible.git
  fi
  cd $CEPH_CHECKOUT_DIR || return 1
  git checkout stable-$VERSION
}

install_prereqs () {
  pip install -U pip || return 1
  pip install -r $CEPH_CHECKOUT_DIR/requirements.txt || return 1
}



place_ceph_configs () {
  # These are pure configuration, no need to back up targets
  cp $CEPH_FILE_DIR/ceph-osds.yml $CEPH_CHECKOUT_DIR/group_vars/osds.yml
  ( diff $CEPH_CHECKOUT_DIR/group_vars/all.yml.sample $CEPH_FILE_DIR/ceph-all-sample.yml ) || { echo "all.yml.sample has changed in the upstream!  RESOLVE."; return 1; }
  cp $CEPH_FILE_DIR/ceph-all.yml $CEPH_CHECKOUT_DIR/group_vars/all.yml
#  ( diff $CEPH_CHECKOUT_DIR/site.yml.sample $CEPH_FILE_DIR/ceph-site-sample.yml ) || { echo "site.yml.sample has changed in the upstream!  RESOLVE."; return 1; }
#  cp $CEPH_FILE_DIR/ceph-site.yml $CEPH_CHECKOUT_DIR/site.yml
#  ( diff $CEPH_CHECKOUT_DIR/group_vars/mons.yml.sample $CEPH_FILE_DIR/ceph-mons-sample.yml ) || { echo "mons.yml.sample has changed in the upstream!  RESOLVE."; return 1; }
#  cp $CEPH_FILE_DIR/ceph-mons.yml $CEPH_CHECKOUT_DIR/group_vars/mons.yml
  ( diff $CEPH_CHECKOUT_DIR/site-container.yml.sample $CEPH_FILE_DIR/ceph-site-container-sample.yml ) || { echo "site-container.yml.sample has changed in the upstream!  RESOLVE."; return 1; }
  cp $CEPH_FILE_DIR/ceph-site-container.yml $CEPH_CHECKOUT_DIR/site-container.yml
  cp $CEPH_FILE_DIR/ceph-hosts $CEPH_CHECKOUT_DIR/hosts
}


place_ceph_hacks () {
  # These are code, corrected for bugs, need to back up.
  # Compare in the future for code drift.  Improve: edit instead of replace.

#  XXX=$CEPH_CHECKOUT_DIR/roles/ceph-osd/tasks/main.yml
#  ( [[ -f $XXX.orig ]] || cp $XXX $XXX.orig )
#  cp $CEPH_FILE_DIR/ceph-main.yml $XXX || return 1

  XXX=$CEPH_CHECKOUT_DIR/roles/ceph-container-common/tasks/fetch_image.yml
  ( [[ -f $XXX.orig ]] || cp $XXX $XXX.orig )
  ( diff $XXX.orig $CEPH_FILE_DIR/ceph-fetch_image-orig.yml ) || { echo "$XXX has changed in the upstream!  RESOLVE."; return 1; }
  cp $CEPH_FILE_DIR/ceph-fetch_image.yml $XXX || return 1

  XXX=$CEPH_CHECKOUT_DIR/roles/ceph-facts/tasks/container_binary.yml
  ( [[ -f $XXX.orig ]] || cp $XXX $XXX.orig )
  ( diff $XXX.orig $CEPH_FILE_DIR/ceph-container_binary-orig.yml ) || { echo "$XXX has changed in the upstream!  RESOLVE."; return 1; }
  cp $CEPH_FILE_DIR/ceph-container_binary.yml $XXX || return 1

  XXX=$CEPH_CHECKOUT_DIR/roles/ceph-container-engine/tasks/pre_requisites/prerequisites.yml
  ( [[ -f $XXX.orig ]] || cp $XXX $XXX.orig )
  ( diff $XXX.orig $CEPH_FILE_DIR/ceph-docker-prerequisites-orig.yml ) || { echo "$XXX has changed in the upstream!  RESOLVE."; return 1; }
  cp $CEPH_FILE_DIR/ceph-docker-prerequisites.yml $XXX || return 1

#  XXX=$CEPH_CHECKOUT_DIR/infrastructure-playbooks/purge-docker-cluster.yml
#  ( [[ -f $XXX.orig ]] || cp $XXX $XXX.orig )
#  cp $CEPH_FILE_DIR/ceph-purge-docker-cluster.yml $XXX || return 1

#  XXX=$CEPH_CHECKOUT_DIR/roles/ceph-dashboard/tasks/configure_dashboard.yml
#  ( [[ -f $XXX.orig ]] || cp $XXX $XXX.orig )
#  cp $CEPH_FILE_DIR/ceph-configure_dashboard.yml $XXX || return 1

}

start_docker_pull () {
  PULLFILE=/tmp/docker_pull.out
  echo "STARTING DOCKER IMAGE PRE-PULL FOR CEPH VERSION: $CEPH_DOCKER_VERSION, SEE $PULLFILE ON STACK_HOSTS" >&2
  HIDE_OUTPUT=$( ssh_control_run_as_user_these_hosts root "docker pull ceph/daemon:$CEPH_DOCKER_VERSION >$PULLFILE 2>&1" "$CLOUD_HOSTS" &&
                 sleep 1 ) &     # Sleep is basically noop - placeholder for when we want to pull sequence of images.
  DOCKER_PULL_PID=$!
}

wait_for_docker_pull () {
  local PID=$1

  echo "WAITING FOR DOCKER PULL TO FINISH... PID: $PID"
  wait $PID 2>/dev/null
  local RC=$?
  if [[ $RC != 0 ]]; then
    echo "Return code for PID $PID: $RC"
    echo "Start_docker_pull returned failure.   Trying once more."
    PID=`start_docker_pull`
    wait $PID 2>/dev/null
    RC=$?
    if [[ $RC != 0 ]]; then
      echo "Failed to pull docker images!"
      echo "Figure it out, human."
      return 1
    fi
  fi
  echo "DOCKER PULL FINISHED"
}

adjust_firewall     || fail_exit "adjust_firewall"
start_docker_pull   || fail_exit "start_docker_pull"

checkout_ceph-ansible_for_dev         || fail_exit "checkout_ceph-ansible_for_dev"
new_venv ceph-ansible                 || fail_exit "new_venv ceph-ansible"
use_venv ceph-ansible                 || fail_exit "use_venv ceph-ansible"
install_prereqs                       || fail_exit "install_prereqs"
place_ceph_configs                    || fail_exit "place_ceph_files"
place_ceph_hacks                      || fail_exit "place_ceph_files"

# export ANSIBLE_DEBUG=true
# export ANSIBLE_VERBOSITY=4

wait_for_docker_pull $DOCKER_PULL_PID || fail_exit "wait_for_docker_pull"
cd $CEPH_CHECKOUT_DIR && ansible-playbook $CEPH_CHECKOUT_DIR/site-container.yml -i $CEPH_CHECKOUT_DIR/hosts -e container_package_name=docker-ce || fail_exit "ansible-playbook"
