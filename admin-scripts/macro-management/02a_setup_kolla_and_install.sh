#!/bin/bash
ADMIN_SETUP_SOURCE="${BASH_SOURCE[0]}"
ADMIN_SETUP_DIR=$( dirname $ADMIN_SETUP_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

NOW=`date +%Y%m%d-%H%M%S`
KOLLA_ANSIBLE_CHECKOUT=~/CODE/feralcoder/kolla-ansible/
LOG_DIR=~/kolla-ansible-logs/


ssh_control_wait_for_host_up_these_hosts "$STACK_HOSTS"

ssh_control_run_as_user cliff "cd CODE/feralcoder; git clone https://feralcoder:`cat ~/.git_password`@github.com/feralcoder/kolla-ansible" dmb

ssh_control_run_as_user cliff "mkdir $LOG_DIR" dmb
ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/setup.sh > $LOG_DIR/01-setup_$NOW.log 2>&1" dmb
ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/make_and_setup_stack_bonds.sh > $LOG_DIR/02-bonds_setup_$NOW.log 2>&1" dmb
ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/test_bonds.sh > $LOG_DIR/03-test-bonds_$NOW.log 2>&1" dmb
ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/validate.sh > $LOG_DIR/04-validate_$NOW.log 2>&1" dmb

os_control_boot_to_target_installation_these_hosts admin "$STACK_HOSTS"
backup_control_backup_all 02_Kolla-Ansible_Setup
os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"

ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy.sh > $LOG_DIR/05-install_$NOW.log 2>&1" dmb

os_control_boot_to_target_installation_these_hosts admin "$STACK_HOSTS"
backup_control_backup_all 03_Kolla-Ansible_Installed
os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"
