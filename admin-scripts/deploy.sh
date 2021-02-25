#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( dirname $KOLLA_SETUP_SOURCE )

kolla-genpwd
ansible -i inventory-feralstack all -m ping
kolla-ansible -i ./inventory-feralstack bootstrap-servers
kolla-ansible -i ./inventory-feralstack prechecks
kolla-ansible -i ./inventory-feralstack deploy
