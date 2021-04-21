#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )

# FROM: https://cloudbase.it/openstack-on-arm64-lbaas/

. $KOLLA_SETUP_DIR/common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }
. /etc/kolla/admin-openrc.sh

source_host_control_scripts       || fail_exit "source_host_control_scripts"

ANSIBLE_CONTROLLER=dmb
SUDO_PASS_FILE=`admin_control_get_sudo_password`    || fail_exit "admin_control_get_sudo_password"



fix_magnum_trust_config () {
  ssh_control_run_as_user_these_hosts root "sed -i 's/^cluster_user_trust.*/cluster_user_trust = True/g' /etc/kolla/magnum-conductor/magnum.conf" "$CONTROL_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker container stop magnum_conductor; docker container start magnum_conductor" "$CONTROL_HOSTS"
}
#fix_magnum_cloud_provider_config () {
#  ssh_control_run_as_user_these_hosts root "sed -i 's/^cluster_user_trust.*/cluster_user_trust = True/g' /etc/kolla/magnum-conductor/magnum.conf" "$CONTROL_HOSTS"
#  ssh_control_run_as_user_these_hosts root "docker container stop magnum_conductor; docker container start magnum_conductor" "$CONTROL_HOSTS"
#}


use_venv kolla-ansible
cat $SUDO_PASS_FILE | sudo -S ls > /dev/null    || return 1
fix_magnum_trust_config                           || fail_exit "fix_magnum_trust_config"

[[ $SUDO_PASS_FILE == ~/.password ]]                || rm $SUDO_PASS_FILE
