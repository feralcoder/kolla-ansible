#!/bin/bash

# RUN ON ANSIBLE CONTROLLER

# BAIL OUT IF USER SOURCES SCRIPT, INSTEAD OF RUNNING IT
if [ ! "${BASH_SOURCE[0]}" -ef "$0" ]; then
  echo "Do not source this script (exits will bail you...)."
  echo "Run it instead"
  return 1
fi

. ~/CODE/venvs/kolla-ansible/bin/activate                                               || fail_exit "venv activate"

KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )


fail_exit () {
  echo; echo "INSTALLATION FAILED AT STEP: $1"
  echo "Check the logs and try again.  Or just give up.  I don't care."
  exit 1
}



echo; echo "REFETCHING HOST KEYS FOR API NETWORK EVERYWHERE"
for HOST in $ALL_HOSTS; do
  ssh_control_run_as_user cliff "ssh_control_refetch_hostkey_these_hosts \"$ALL_HOSTS_API_NET\"" $HOST 2>/dev/null  || fail_exit "ssh_control_refetch_hostkey_these_hosts"
done


kolla-genpwd                                                                             || fail_exit "kolla-genpwd"
ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack all -m ping              || fail_exit "ansible ping"
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack bootstrap-servers  || fail_exit "kolla-ansible bootstrap-servers"
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack prechecks          || fail_exit "kolla-ansible prechecks"


