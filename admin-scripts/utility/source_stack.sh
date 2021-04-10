#!/bin/bash -e
UTILITY_SOURCE="${BASH_SOURCE[0]}"
UTILITY_DIR=$( realpath `dirname $UTILITY_SOURCE` )
# RUN ON ANSIBLE CONTROLLER

. $UTILITY_DIR/../common.sh
[ ! "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't run this script!  Source it."; return 1; }

source_host_control_scripts
use_venv kolla-ansible

. /etc/kolla/admin-openrc.sh
