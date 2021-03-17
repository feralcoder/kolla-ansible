#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )

# BAIL OUT IF USER SOURCES SCRIPT, INSTEAD OF RUNNING IT
if [ ! "${BASH_SOURCE[0]}" -ef "$0" ]; then
  echo "Do not source this script (exits will bail you...)."
  echo "Run it instead"
  return 1
fi

. ~/CODE/venvs/kolla-ansible/bin/activate
. ~/CODE/feralcoder/host_control/control_scripts.sh

fail_exit () {
  echo; echo "INSTALLATION FAILED AT STEP: $1"
  echo "Check the logs and try again.  Or just give up.  I don't care."
  exit 1
}

adjust_firewall () {
  echo; echo ", AND POKING HOLE IN FIREWALL"
  ssh_control_run_as_user_these_hosts root "systemd disable firewalld" "$STACK_HOSTS"                    || return 1
  ssh_control_run_as_user_these_hosts root "systemd stop firewalld" "$STACK_HOSTS"                       || return 1
#  ssh_control_run_as_user_these_hosts root "firewall-cmd --zone=public --add-port=4567/tcp" "$CONTROL_HOSTS"                    || return 1
#  ssh_control_run_as_user_these_hosts root "firewall-cmd --permanent --zone=public --add-port=4567/tcp" "$CONTROL_HOSTS"        || return 1
}

# I FEEL LIKE THE kolla-ansible DEPLOYER'S BROKEN...
adjust_firewall

# PULL CONTAINER IMAGES AHEAD OF DEPLOY.  Pull twice if needed...
kolla-ansible -i $KOLLA_SETUP_DIR/../files/inventory-feralstack pull || kolla-ansible -i $KOLLA_SETUP_DIR../files/inventory-feralstack pull || fail_exit "kolla-ansible pull"

# DEPLOY THE STACK!!!
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack deploy || fail_exit "kolla-ansible deploy"
