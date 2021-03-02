#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( dirname $KOLLA_SETUP_SOURCE )

echo; echo "REFETCHING HOST KEYS FOR API NETWORK EVERYWHERE"
ssh_control_run_as_user_these_hosts cliff "ssh_control_refetch_hostkey_these_hosts \"$ALL_HOSTS_API_NET\"" "$ALL_HOSTS" 2>/dev/null


kolla-ansible -i ../files/inventory-feralstack deploy
