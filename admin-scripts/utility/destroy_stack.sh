#!/bin/bash
UTILITY_SOURCE="${BASH_SOURCE[0]}"
UTILITY_DIR=$( realpath `dirname $UTILITY_SOURCE` )
# RUN ON ANSIBLE CONTROLLER

. $UTILITY_DIR/../common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"
use_venv kolla-ansible            || fail_exit "use_venv kolla-ansible"



SERVERS=`openstack server list | grep -v '\-\-\-\-\|ID' | awk '{print $2}'`
for SERVER in $SERVERS; do
  openstack server delete $SERVER
done

kolla-ansible -i $UTILITY_DIR/../../files/kolla-inventory-feralstack destroy     --yes-i-really-really-mean-it && 
$UTILITY_DIR/../07-deploy-kolla.sh && 
$UTILITY_DIR/../08-post-deploy-kolla.sh
