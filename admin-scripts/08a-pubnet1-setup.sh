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




configure_pubnet1_net () {
  PROVIDER_SUBNET=172.30.1.0/24
  PROVIDER_SUBNET_START=172.30.1.10
  PROVIDER_SUBNET_END=172.30.1.254
  PROVIDER_ROUTER_IP=172.30.1.241/24
  PROVIDER_VIRTROUTER_IP=172.30.1.1/24
  PROVIDER_VLAN_ID=201
  PROVIDER_NETNAME=pubnet1
}





use_venv kolla-ansible

configure_pubnet1_net                          || fail_exit "configure_pubnet1_net"
setup_provider_net $PROVIDER_NETNAME $PROVIDER_VLAN_ID $PROVIDER_SUBNET $PROVIDER_ROUTER_IP $PROVIDER_SUBNET_START $PROVIDER_SUBNET_END  || fail_exit "setup_provider_net"

[[ $SUDO_PASS_FILE == ~/.password ]]                || rm $SUDO_PASS_FILE
