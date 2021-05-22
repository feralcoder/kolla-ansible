#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )
SUDO_PASS_FILE=~/.password

. $KOLLA_SETUP_DIR/common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"
use_venv kolla-ansible            || fail_exit "use_venv kolla-ansible"

REGISTRY_HOST=dmb
# Bail out if not running on registry host
if [[ $(group_logic_get_short_name `hostname`) != $REGISTRY_HOST ]]; then
  echo "You must run this script on the registry host, which should also be the ansile host."
  exit 1
fi




refetch_api_keys () {
  echo; echo "REFETCHING HOST KEYS FOR API NETWORK EVERYWHERE"
  for HOST in $ALL_HOSTS; do
    ssh_control_run_as_user cliff "ssh_control_refetch_hostkey_these_hosts \"$STACK_HOSTS_API_NET\"" $HOST 2>/dev/null  || fail_exit "ssh_control_refetch_hostkey_these_hosts"
  done
}

use_localized_containers () {
  # Switch back to local (pinned) fetches for deployment
  cp $KOLLA_SETUP_DIR/../files/kolla-globals-localpull.yml /etc/kolla/globals.yml         ||  return 1
  cat $KOLLA_SETUP_DIR/../files/kolla-globals-remainder.yml >> /etc/kolla/globals.yml     ||  return 1
  [[ ! -f /etc/kolla/globals-octavia.yml ]] || cat /etc/kolla/globals-octavia.yml >> /etc/kolla/globals.yml     ||  return 1
}

generate_ssl_certs () {
  kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack certificates                                           || return 1

}

untar_ssl_certs () {
#  SELF-SIGNED CERTS DON'T WORK IN KOLLA-ANSIBLE AS DOCUMENTED
#
#  # DO ONCE: Have kolla-ansible generate certs, then stash them into git://feralcoder (encrypted)
#  #  Also place stack's root ca for building into base container image.
#  kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack certificates       || return 1
#  tar -C /etc/kolla -cf $KOLLA_SETUP_DIR/../files/kolla-certificates.tar certificates
#  openssl enc -aes-256-cfb8 --pass file:/home/cliff/.password -md sha256 -in $KOLLA_SETUP_DIR/../files/kolla-certificates.tar -out $KOLLA_SETUP_DIR/../files/kolla-certificates.encrypted
#  # PLACE root CA into base image container.  REBUILD CONTAINERS!
#  cp /etc/kolla/certificates/ca/root.crt $KOLLA_SETUP_DIR/utility/docker-images/centos-feralcoder/stack.crt
#
#  # AFTER REGENERATION: copy /etc/kolla/certificates/ca/root.crt into all containers.
#  #   The root.crt will be copied as stack.crt into base container build directory
#  #   Containers must then be rebuilt, via build_and_use_containers

  openssl enc --pass file:/home/cliff/.password -d -aes-256-cfb8 -md sha256 -in $KOLLA_SETUP_DIR/../files/kolla-certificates.encrypted -out $KOLLA_SETUP_DIR/../files/kolla-certificates.tar
  tar -C /etc/kolla -xf $KOLLA_SETUP_DIR/../files/kolla-certificates.tar
  tar -C /tmp/testcerts -xf $KOLLA_SETUP_DIR/../files/kolla-certificates.tar
#  ssh_control_sync_as_user_these_hosts root /etc/kolla/certificates/ca/root.crt /etc/pki/ca-trust/source/anchors/stack.crt "$ALL_HOSTS"
#  ssh_control_run_as_user_these_hosts root update-ca-trust "$ALL_HOSTS"
}


fix_kolla_configs () {
  XXX=/home/cliff/CODE/venvs/kolla-ansible/share/kolla-ansible/ansible/roles/swift/defaults/main.yml
  ( [[ -f $XXX.orig ]] || cp $XXX $XXX.orig )
  ( diff $XXX.orig $KOLLA_SETUP_DIR/../files/kolla-swift-defaults-main-orig.yml ) || { echo "$XXX has changed in the upstream!  RESOLVE."; return 1; }
  cp $KOLLA_SETUP_DIR/../files/kolla-swift-defaults-main.yml $XXX || return 1

  XXX=/home/cliff/CODE/venvs/kolla-ansible/share/kolla-ansible/ansible/roles/swift/templates/proxy-server.conf.j2
  ( [[ -f $XXX.orig ]] || cp $XXX $XXX.orig )
  ( diff $XXX.orig $KOLLA_SETUP_DIR/../files/kolla-swift-templates-proxy-server.conf-orig.yml ) || { echo "$XXX has changed in the upstream!  RESOLVE."; return 1; }
  cp $KOLLA_SETUP_DIR/../files/kolla-swift-templates-proxy-server.conf.yml $XXX || return 1

  XXX=/home/cliff/CODE/venvs/kolla-ansible/share/kolla-ansible/ansible/roles/neutron/templates/ml2_conf.ini.j2
  ( [[ -f $XXX.orig ]] || cp $XXX $XXX.orig )
  ( diff $XXX.orig $KOLLA_SETUP_DIR/../files/kolla-ml2_conf.ini-orig.j2 ) || { echo "$XXX has changed in the upstream!  RESOLVE."; return 1; }
  cp $KOLLA_SETUP_DIR/../files/kolla-ml2_conf.ini.j2 $XXX || return 1
}


configure_octavia () {
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo mkdir -p /etc/kolla/config/octavia
  # Use a config drive in the Amphorae for cloud-init
  sudo tee /etc/kolla/config/octavia/octavia-worker.conf << EOT
[controller_worker]
user_data_config_drive = true
EOT
}

configure_manila () {
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo mkdir -p /etc/kolla/config/
  sudo tee /etc/kolla/config/manila-share.conf << EOT
[generic]
service_instance_flaver_id = 100
EOT
}


#refetch_api_keys                                                                         || fail_exit "refetch_api_keys"
kolla-genpwd                                                                             || fail_exit "kolla-genpwd"
ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack all -m ping              || fail_exit "ansible ping"

## Use local registry so insecure-registries is set up correctly by bootstrap-servers
use_localized_containers                                                                 || fail_exit "use_localized_containers"
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack bootstrap-servers  || fail_exit "kolla-ansible bootstrap-servers"

fix_kolla_configs                                                                        || fail_exit "fix_kolla_configs"

generate_ssl_certs                                                                          || fail_exit "setup_ssl_certs"
#untar_ssl_certs
kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack prechecks          || fail_exit "kolla-ansible prechecks"

configure_octavia
configure_manila
