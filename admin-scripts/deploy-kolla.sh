#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )

. ~/CODE/venvs/kolla-ansible/bin/activate

kolla-ansible -i ../files/inventory-feralstack deploy
