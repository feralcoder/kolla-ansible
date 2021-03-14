#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( realpath `dirname $MACRO_SOURCE` )

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

os_control_boot_to_target_installation_these_hosts admin "$STACK_HOSTS"
backup_control_restore_all 02b_Ceph_Setup
os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"

# Run: post-deploy-ceph.sh,  deploy-kolla.sh
echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/post-deploy-ceph.sh ON $ANSIBLE_CONTROLLER"
ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/post-deploy-ceph.sh > $LOG_DIR/07-post-deploy-ceph_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 7: Post-Deploy Ceph"
echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-kolla.sh ON $ANSIBLE_CONTROLLER"
ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-kolla.sh > $LOG_DIR/08-deploy-kolla_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 8: Stack Deployment"


os_control_boot_to_target_installation_these_hosts admin "$STACK_HOSTS"
backup_control_backup_all 03_Kolla-Ansible_Installed
os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"
