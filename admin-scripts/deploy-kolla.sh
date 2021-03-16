#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )

. ~/CODE/venvs/kolla-ansible/bin/activate

fail_exit () {
  echo; echo "INSTALLATION FAILED AT STEP: $1"
  echo "Check the logs and try again.  Or just give up.  I don't care."
  exit 1
}


# PULL CONTAINER IMAGES AHEAD OF DEPLOY.  Pull twice if needed...
kolla-ansible -i ../files/inventory-feralstack pull || kolla-ansible -i ../files/inventory-feralstack pull

# DEPLOY THE STACK!!!
kolla-ansible -i ../files/kolla-inventory-feralstack deploy
