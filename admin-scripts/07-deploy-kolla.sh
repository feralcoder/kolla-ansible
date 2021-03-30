#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )

. $KOLLA_SETUP_DIR/common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts         || fail_exit "source_host_control_scripts"
use_venv kolla-ansible              || fail_exit "use_venv kolla-ansible"


use_localized_containers () {
  # Switch back to local (pinned) fetches for deployment
  cp $KOLLA_SETUP_DIR/../files/kolla-globals-localpull.yml /etc/kolla/globals.yml         ||  return 1
  cat $KOLLA_SETUP_DIR/../files/kolla-globals-remainder.yml >> /etc/kolla/globals.yml     ||  return 1
}

adjust_firewall () {
  echo; echo "DISABLING FIREWALL again."
  ssh_control_run_as_user_these_hosts root "systemctl disable firewalld" "$STACK_HOSTS"                    || return 1
  ssh_control_run_as_user_these_hosts root "systemctl stop firewalld" "$STACK_HOSTS"                       || return 1
#  ssh_control_run_as_user_these_hosts root "firewall-cmd --zone=public --add-port=4567/tcp" "$CONTROL_HOSTS"                    || return 1
#  ssh_control_run_as_user_these_hosts root "firewall-cmd --permanent --zone=public --add-port=4567/tcp" "$CONTROL_HOSTS"        || return 1
}

# I FEEL LIKE THE kolla-ansible DEPLOYER'S BROKEN...
adjust_firewall

# Reset globals.yml in case it's been updated
use_localized_containers
# PULL CONTAINER IMAGES AHEAD OF DEPLOY.  Pull twice if needed...
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack pull || kolla-ansible -i $KOLLA_SETUP_DIR../files/kolla-inventory-feralstack pull || fail_exit "kolla-ansible pull"

# DEPLOY THE STACK!!!
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack deploy || fail_exit "kolla-ansible deploy"
