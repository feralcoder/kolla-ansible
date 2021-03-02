#!/bin/bash

# RUN ON ANSIBLE CONTROLLER

. ~/CODE/venvs/kolla-ansible/bin/activate

KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( dirname $KOLLA_SETUP_SOURCE )


kolla-genpwd
ansible -i $KOLLA_SETUP_DIR/../files/inventory-feralstack all -m ping
kolla-ansible -i $KOLLA_SETUP_DIR/../files/inventory-feralstack bootstrap-servers
kolla-ansible -i $KOLLA_SETUP_DIR/../files/inventory-feralstack prechecks
