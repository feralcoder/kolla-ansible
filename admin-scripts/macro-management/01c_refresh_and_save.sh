#!/bin/bash
ADMIN_SETUP_SOURCE="${BASH_SOURCE[0]}"
ADMIN_SETUP_DIR=$( dirname $ADMIN_SETUP_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

# This script will restore the Ansible Controller as well as all $CLOUD_HOSTS
# Run from admin box (yoda)


host_control_updates () {
  git_control_pull_push_these_hosts "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts cliff "/home/cliff/CODE/feralcoder/workstation/update.sh" "$ALL_HOSTS"

  # Serialize to not overwhelm ILO ports
  for HOST in $ALL_HOSTS; do
     ssh_control_run_as_user cliff "ilo_control_refetch_ilo_hostkey_these_hosts \"$ALL_HOSTS\"" $HOST
  done
  ssh_control_run_as_user_these_hosts cliff "ssh_control_refetch_hostkey_these_hosts \"$ALL_HOSTS\"" "$ALL_HOSTS"
}


os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"

admin_control_fix_grub_these_hosts "$STACK_HOSTS"
host_control_updates

os_control_checkout_repofetcher dmb
ssh_control_run_as_user root "/home/cliff/CODE/feralcoder/repo-fetcher/setup.sh" dmb

os_control_checkout_repofetcher yda
os_control_repoint_repos_to_feralcoder_these_hosts "$ALL_HOSTS"
ssh_control_run_as_user root "dnf -y upgrade" "$STACK_HOSTS"

os_control_boot_to_target_installation_these_hosts admin "$STACK_HOSTS"
backup_control_backup_all 01_CentOS_8_3_Admin_Install
os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"
