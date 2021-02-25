#!/bin/bash
ADMIN_SETUP_SOURCE="${BASH_SOURCE[0]}"
ADMIN_SETUP_DIR=$( dirname $ADMIN_SETUP_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

os_control_boot_to_target_installation_these_hosts admin "$STACK_HOSTS"
backup_control_restore_all 02_Kolla-Ansible_Setup
os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"

ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy.sh > $LOG_DIR/03-install_$NOW.log 2>&1" dmb

os_control_boot_to_target_installation_these_hosts admin "$STACK_HOSTS"
backup_control_backup_all 03_Kolla-Ansible_Installed
os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"
