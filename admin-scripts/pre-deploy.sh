#!/bin/bash

# RUN ON ANSIBLE CONTROLLER

# BAIL OUT IF USER SOURCES SCRIPT, INSTEAD OF RUNNING IT
if [ ! "${BASH_SOURCE[0]}" -ef "$0" ]; then
  echo "Do not source this script (exits will bail you...)."
  echo "Run it instead"
  return 1
fi

. ~/CODE/venvs/kolla-ansible/bin/activate

KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )


fail_exit () {
  echo; echo "INSTALLATION FAILED AT STEP: $1"
  echo "Check the logs and try again.  Or just give up.  I don't care."
  exit 1
}



echo; echo "REFETCHING HOST KEYS FOR API NETWORK EVERYWHERE"
for HOST in $ALL_HOSTS; do
  ssh_control_run_as_user cliff "ssh_control_refetch_hostkey_these_hosts \"$ALL_HOSTS_API_NET\"" $HOST 2>/dev/null
done  || { echo "Could not refetch hostkeys on all hosts"; }


kolla-genpwd
ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack all -m ping
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack bootstrap-servers
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack prechecks


