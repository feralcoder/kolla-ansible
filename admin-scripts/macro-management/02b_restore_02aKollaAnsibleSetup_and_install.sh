#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( realpath `dirname $MACRO_SOURCE` )

# BAIL OUT IF USER SOURCES SCRIPT, INSTEAD OF RUNNING IT
if [ ! "${BASH_SOURCE[0]}" -ef "$0" ]; then
  echo "Do not source this script (exits will bail you...)."
  echo "Run it instead"
  return 1
fi

. ~/CODE/feralcoder/host_control/control_scripts.sh

NOW=`date +%Y%m%d-%H%M%S`
KOLLA_ANSIBLE_CHECKOUT=~/CODE/feralcoder/kolla-ansible/
LOG_DIR=~/kolla-ansible-logs/
ANSIBLE_CONTROLLER=dmb

fail_exit () {
  echo; echo "INSTALLATION FAILED AT STEP: $1"
  echo "Check the logs and try again.  Or just give up.  I don't care."
  exit 1
}

boot_to_target () {
  local TARGET=$1
  [[ $TARGET == "admin" ]] || [[ $TARGET == "default" ]] || fail_exit "boot_to_target - target must be 'admin' or 'default'!"

  # Boot all hosts to default / admin
  os_control_boot_to_target_installation_these_hosts $TARGET "$STACK_HOSTS" || exit 1
  ssh_control_wait_for_host_up_these_hosts "$STACK_HOSTS" || exit 1
  os_control_assert_hosts_booted_target $TARGET "$STACK_HOSTS" || {
    echo "All stack hosts must be in their $TARGET OS to install the stack!"
    exit 1
  }
}

restore_from_backup () {
  local BACKUP_NAME=$1

  echo; echo "BOOTING ALL STACK HOSTS TO ADMIN OS FOR RESTORE OPERATION: $STACK_HOSTS"
  boot_to_target admin || exit 1
  echo; echo "RESTORING STACK_HOSTS $BACKUP_NAME: $STACK_HOSTS"
  backup_control_restore_all $BACKUP_NAME || exit 1
  echo; echo "BOOTING ALL STACK HOSTS TO DEFAULT OS: $STACK_HOSTS"
  boot_to_target default || exit 1
}


deploy_ceph () {
  # Run: deploy-ceph.sh
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-ceph.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-ceph.sh > $LOG_DIR/06-deploy-ceph_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 6: Deploy Ceph"
}


deploy_kolla () {
  # Run: post-deploy-ceph.sh,  deploy-kolla.sh
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/post-deploy-ceph.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/post-deploy-ceph.sh > $LOG_DIR/07-post-deploy-ceph_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 7: Post-Deploy Ceph"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-kolla.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-kolla.sh > $LOG_DIR/08-deploy-kolla_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 8: Stack Deployment"
}


reset_OSDs () {
  MAP=`ceph_control_show_map`
  ceph_control_wipe_LVM_OSDs_from_map_these_hosts "$MAP" "$COMPUTE_HOSTS" || exit 1
  ceph_control_create_LVM_OSDs_from_map_these_hosts "$MAP" "$COMPUTE_HOSTS" || exit 1
}


restore_from_backup 02b_Ceph_Setup || fail_exit "restore_from_backup 02b_Ceph_Setup"
reset_OSDs || fail_exit "reset_OSDs"


# ASSUME WE COULD BE STARTING FROM A FREEZE-THAW...
ssh_control_run_as_user cliff "cd CODE/feralcoder/kolla-ansible; git pull" $ANSIBLE_CONTROLLER || fail_exit "git pull kolla-ansible"

deploy_ceph || fail_exit "deploy_ceph"
take_backups 02b_Ceph_Setup || fail_exit "take_backups 02b_Ceph_Setup"
# NEED CEPH EXPORT FUNCTION

# ASSUME WE COULD BE STARTING FROM A FREEZE-THAW...
ssh_control_run_as_user cliff "cd CODE/feralcoder/kolla-ansible; git pull" $ANSIBLE_CONTROLLER || fail_exit "git pull kolla-ansible"

deploy_kolla || fail_exit "deploy_kolla"
take_backups 03_Kolla-Ansible_Installed || fail_exit "take_backups 03_Kolla-Ansible_Installed"
