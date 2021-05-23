#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )

. $KOLLA_SETUP_DIR/common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"
use_venv kolla-ansible            || fail_exit "use_venv kolla-ansible"

ANSIBLE_CONTROLLER=dmb
FERALSTACK_SETUP_DIR=~/CODE/feralcoder/feralstack


cd $FERALSTACK_SETUP_DIR && git pull || fail_exit "update $FERALSTACK_SETUP_DIR"


~/CODE/feralcoder/playlister-orchestrator/01a_setup_playlister.sh
~/CODE/feralcoder/playlister-orchestrator/01b_playlister-quotas.sh
~/CODE/feralcoder/playlister-orchestrator/02_deploy_heatstack.sh
#~/CODE/feralcoder/playlister-orchestrator/03_manage_heatstack.sh
