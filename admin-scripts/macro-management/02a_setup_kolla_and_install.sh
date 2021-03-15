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

## Boot all hosts to default
#echo; echo "BOOTING ALL STACK HOSTS TO DEFAULT OS: $STACK_HOSTS"
#os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"
#ssh_control_wait_for_host_up_these_hosts "$STACK_HOSTS"
#os_control_assert_hosts_booted_target default "$STACK_HOSTS" || {
#  echo "All stack hosts must be in their default OS to install the stack!"
#  exit 1
#}
#
## Checkout / update kolla-ansible on ansible controller
#echo; echo "CHECKING OUT / UPDATING ~CODE/feralcoder/kolla-ansible ON ANSIBLE_CONTROLLER: $ANSIBLE_CONTROLLER"
#ssh_control_run_as_user cliff "cd CODE/feralcoder; [[ -d kolla-ansible ]] || git clone https://feralcoder:`cat ~/.git_password`@github.com/feralcoder/kolla-ansible" $ANSIBLE_CONTROLLER
#ssh_control_run_as_user cliff "cd CODE/feralcoder/kolla-ansible; git pull" $ANSIBLE_CONTROLLER
#
## Set up stack user password
#echo; echo "SETTING stack USER PASSWORD ON ANSIBLE_CONTROLLER: $ANSIBLE_CONTROLLER"
#STACKPASSFILE=`ssh_control_get_password ~/.stack_password false`
#ssh_control_sync_as_user cliff ~/.stack_password ~/.stack_password $ANSIBLE_CONTROLLER
#ssh_control_run_as_user cliff "chmod 600 ~/.stack_password" $ANSIBLE_CONTROLLER
#
## Run: setup-kolla.sh,   make_and_setup_stack_bonds.sh,   test_bonds.sh,   pre-deploy.sh,   deploy-registry.sh
#echo; echo "SETTING UP LOG DIRECTORY $LOG_DIR ON $ANSIBLE_CONTROLLER.  GO THERE FOR PROGRESS OUTPUT."
#ssh_control_run_as_user cliff "mkdir $LOG_DIR" $ANSIBLE_CONTROLLER
#echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/setup-kolla.sh ON $ANSIBLE_CONTROLLER"
#ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/setup-kolla.sh > $LOG_DIR/01-setup-kolla_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 1: Kolla Host Setup"
#echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/make_and_setup_stack_bonds.sh ON $ANSIBLE_CONTROLLER"
#ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/make_and_setup_stack_bonds.sh > $LOG_DIR/02-bonds_setup_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 2: Bond Setup"
#echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/util/test_bonds.sh ON $ANSIBLE_CONTROLLER"
#ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/util/test_bonds.sh > $LOG_DIR/03-test-bonds_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 3: Test Bonds"
#echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/pre-deploy.sh ON $ANSIBLE_CONTROLLER"
#ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/pre-deploy.sh > $LOG_DIR/04-pre-deploy_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 4: Kolla Pre Deployment"
#echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-registry.sh ON $ANSIBLE_CONTROLLER"
#ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-registry.sh > $LOG_DIR/05-deploy-registry_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 5: Registry Deployment"


## Take backups now: 02a_Kolla-Ansible_Setup
#echo; echo "BOOTING ALL STACK HOSTS TO ADMIN OS FOR BACKUP OPERATION: $STACK_HOSTS"
#os_control_boot_to_target_installation_these_hosts admin "$STACK_HOSTS"
#echo; echo "BACKING UP STACK_HOSTS 02a_Kolla-Ansible_Setup: $STACK_HOSTS"
#backup_control_backup_all 02a_Kolla-Ansible_Setup
#echo; echo "BOOTING ALL STACK HOSTS TO DEFAULT OS: $STACK_HOSTS"
#os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"
#os_control_assert_hosts_booted_target default "$STACK_HOSTS" || {
#  echo "All stack hosts must be in their default OS to install the stack!"
#  exit 1
#}
#

# ASSUME WE COULD BE STARTING FROM A FREEZE-THAW...
ssh_control_run_as_user cliff "cd CODE/feralcoder/kolla-ansible; git pull" $ANSIBLE_CONTROLLER

# Run: deploy-ceph.sh
echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-ceph.sh ON $ANSIBLE_CONTROLLER"
ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-ceph.sh > $LOG_DIR/06-deploy-ceph_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 6: Deploy Ceph"


## Take backups now: 02b_Ceph_Setup
#echo; echo "BOOTING ALL STACK HOSTS TO ADMIN OS FOR BACKUP OPERATION: $STACK_HOSTS"
#os_control_boot_to_target_installation_these_hosts admin "$STACK_HOSTS"
#echo; echo "BACKING UP STACK_HOSTS 02b_Ceph_Setup: $STACK_HOSTS"
#backup_control_backup_all 02b_Ceph_Setup
#echo; echo "BOOTING ALL STACK HOSTS TO DEFAULT OS: $STACK_HOSTS"
#os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"
#os_control_assert_hosts_booted_target default "$STACK_HOSTS" || {
# #echo "All stack hosts must be in their default OS to install the stack!"
# #exit 1
#}
#
## ASSUME WE COULD BE STARTING FROM A FREEZE-THAW...
#ssh_control_run_as_user cliff "cd CODE/feralcoder/kolla-ansible; git pull" $ANSIBLE_CONTROLLER
#
#
## Run: post-deploy-ceph.sh,  deploy-kolla.sh
#echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/post-deploy-ceph.sh ON $ANSIBLE_CONTROLLER"
#ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/post-deploy-ceph.sh > $LOG_DIR/07-post-deploy-ceph_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 7: Post-Deploy Ceph"
#echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-kolla.sh ON $ANSIBLE_CONTROLLER"
#ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-kolla.sh > $LOG_DIR/08-deploy-kolla_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 8: Stack Deployment"
#
#
## Take backups now: 03_Kolla-Ansible_Installed
#echo; echo "BOOTING ALL STACK HOSTS TO ADMIN OS FOR BACKUP OPERATION: $STACK_HOSTS"
#os_control_boot_to_target_installation_these_hosts admin "$STACK_HOSTS"
#echo; echo "BACKING UP STACK_HOSTS 03_Kolla-Ansible_Installed: $STACK_HOSTS"
#backup_control_backup_all 03_Kolla-Ansible_Installed
#echo; echo "BOOTING ALL STACK HOSTS TO DEFAULT OS: $STACK_HOSTS"
#os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"
