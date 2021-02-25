#!/bin/bash
ADMIN_SETUP_SOURCE="${BASH_SOURCE[0]}"
ADMIN_SETUP_DIR=$( dirname $KOLLA_SETUP_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

# This script will restore the Ansible Controller as well as all $CLOUD_HOSTS
# Run from admin box (yoda)




host_control_updates () {
  git_control_pull_push_these_hosts "$ALL_HOSTS"

  for host in $ALL_HOSTS; do
     ssh_control_run_as_user cliff "ilo_control_refetch_ilo_hostkey_these_hosts \"$ALL_HOSTS\"" $HOST
     ssh_control_run_as_user cliff "ssh_control_refetch_hostkey_these_hosts \"$ALL_HOSTS\"" $HOST
     ssh_control_run_as_user cliff "./CODE/feralcoder/workstation/update.sh" $HOST                    # Set up /etc/hosts
  done
}


os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"

admin_control_fix_grub_these_hosts "$STACK_HOSTS"
host_control_update

os_control_checkout_repofetcher dmb
ssh_control_run_as_user root "/home/cliff/CODE/feralcoder/repo-fetcher/setup.sh" dmb

os_control_checkout_repofetcher yda
os_control_repoint_repos_to_feralcoder_these_hosts "$ALL_HOSTS"
ssh_control_run_as_user root "dnf -y upgrade" "$STACK_HOSTS"

os_control_boot_to_target_installation_these_hosts admin "$STACK_HOSTS"
backup_control_backup_all 01_CentOS_8_3_Admin_Install
os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"
