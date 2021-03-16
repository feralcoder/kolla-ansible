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

fail_exit () {
  echo; echo "INSTALLATION FAILED AT STEP: $1"
  echo "Check the logs and try again.  Or just give up.  I don't care."
  exit 1
}


# PULL CONTAINER IMAGES AHEAD OF DEPLOY.  Pull twice if needed...
kolla-ansible -i $KOLLA_SETUP_DIR/../files/inventory-feralstack pull || kolla-ansible -i ../files/inventory-feralstack pull || fail_exit "kolla-ansible pull"

# DEPLOY THE STACK!!!
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack deploy || fail_exit "kolla-ansible deploy"
