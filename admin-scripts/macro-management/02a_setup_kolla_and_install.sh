#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

NOW=`date +%Y%m%d-%H%M%S`
KOLLA_ANSIBLE_CHECKOUT=~/CODE/feralcoder/kolla-ansible/
LOG_DIR=~/kolla-ansible-logs/
ANSIBLE_CONTROLLER=dmb
STACKPASS=st@ck


os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"
ssh_control_wait_for_host_up_these_hosts "$STACK_HOSTS"
os_control_assert_hosts_booted_target default "$STACK_HOSTS" || {
  echo "All stack hosts must be in their default OS to install the stack!"
  exit 1
}

ssh_control_run_as_user cliff "cd CODE/feralcoder; [[ -d kolla-ansible ]] || git clone https://feralcoder:`cat ~/.git_password`@github.com/feralcoder/kolla-ansible" $ANSIBLE_CONTROLLER
ssh_control_run_as_user cliff "cd CODE/feralcoder/kolla-ansible; git pull" $ANSIBLE_CONTROLLER

echo $STACKPASS > ~/.stack_password && chmod 600 ~/.stack_password
ssh_control_sync_as_user cliff /.stack_password /.stack_password $ANSIBLE_CONTROLLER
ssh_control_run_as_user cliff "chmod 600 ~/.stack_password" $ANSIBLE_CONTROLLER

ssh_control_run_as_user cliff "mkdir $LOG_DIR" $ANSIBLE_CONTROLLER
ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/setup.sh > $LOG_DIR/01-setup_$NOW.log 2>&1" $ANSIBLE_CONTROLLER
ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/make_and_setup_stack_bonds.sh > $LOG_DIR/02-bonds_setup_$NOW.log 2>&1" $ANSIBLE_CONTROLLER
ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/util/test_bonds.sh > $LOG_DIR/03-test-bonds_$NOW.log 2>&1" $ANSIBLE_CONTROLLER
ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/validate.sh > $LOG_DIR/04-validate_$NOW.log 2>&1" $ANSIBLE_CONTROLLER

os_control_boot_to_target_installation_these_hosts admin "$STACK_HOSTS"
backup_control_backup_all 02_Kolla-Ansible_Setup
os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"

ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy.sh > $LOG_DIR/05-install_$NOW.log 2>&1" $ANSIBLE_CONTROLLER

os_control_boot_to_target_installation_these_hosts admin "$STACK_HOSTS"
backup_control_backup_all 03_Kolla-Ansible_Installed
os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"
