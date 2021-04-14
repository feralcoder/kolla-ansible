#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )

. $KOLLA_SETUP_DIR/common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"
use_venv kolla-ansible            || fail_exit "use_venv kolla-ansible"

ANSIBLE_CONTROLLER=dmb


~/CODE/feralcoder/feralstack/01_quotas.sh
~/CODE/feralcoder/feralstack/01_upload_images.sh
~/CODE/feralcoder/feralstack/02_setup_admin_instances.sh
#~/CODE/feralcoder/feralstack/02_kubernetes_wordpress.sh
