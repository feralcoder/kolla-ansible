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



setup_octavia_in_globals () {
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null    || return 1
  echo "octavia_certs_country: US" | sudo tee -a /etc/kolla/globals.yml
  echo "octavia_certs_state: California" | sudo tee -a /etc/kolla/globals.yml
  echo "octavia_certs_organization: FeralStack" | sudo tee -a /etc/kolla/globals.yml
  echo "octavia_certs_organizational_unit: Octavia" | sudo tee -a /etc/kolla/globals.yml
}

configure_octavia_net () {
  PROVIDER_SUBNET=172.31.0.0/24
  PROVIDER_SUBNET_START=172.31.0.10
  PROVIDER_SUBNET_END=172.31.0.254
  PROVIDER_ROUTER_IP=172.31.0.241/24
  PROVIDER_VIRTROUTER_IP=172.31.0.1/24
  PROVIDER_VLAN_ID=131
  PROVIDER_NETNAME=lbaas
  
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null    || return 1
  sudo tee -a /etc/kolla/globals.yml << EOT
octavia_amp_network:
  name: lb-mgmt-net
  provider_network_type: vlan
  provider_segmentation_id: $PROVIDER_VLAN_ID
  provider_physical_network: physnet1
  external: false
  shared: false
  subnet:
    name: lb-mgmt-subnet
    cidr: "$PROVIDER_SUBNET"
    allocation_pool_start: "$PROVIDER_SUBNET_START"
    allocation_pool_end: "$PROVIDER_SUBNET_END"
    gateway_ip: "$PROVIDER_VIRTROUTER_IP"
    enable_dhcp: yes
EOT
}



configure_octavia () {
  echo "enable_octavia: \"yes\"" >> /etc/kolla/globals.yml
  echo "octavia_network_interface: v-lbaas" >> /etc/kolla/globals.yml
 
  # Flavor used when booting an amphora, change as needed
  sudo tee -a /etc/kolla/globals.yml << EOT
octavia_amp_flavor:
  name: "amphora"
  is_public: no
  vcpus: 1
  ram: 1024
  disk: 5
EOT

  sudo mkdir -p /etc/kolla/config/octavia
  # Use a config drive in the Amphorae for cloud-init
  sudo tee /etc/kolla/config/octavia/octavia-worker.conf << EOT
[controller_worker]
user_data_config_drive = true
EOT
}


deploy_octavia () {
  kolla-ansible -i $KOLLA_SETUP_DIR/../files/kolla-inventory-feralstack deploy --tags common,horizon,octavia,neutron
}


build_amphora () {
  [[ -d ~/CODE/openstack/octavia ]] || { mkdir -p  ~/CODE/openstack/ && cd  ~/CODE/openstack/ && git clone https://github.com/openstack/octavia; }

  cd $KOLLA_SETUP_DIR/utility/docker-images/

  # Centos
  docker build amphora-image-amd64-docker -f amphora-image-amd64-docker/Dockerfile.Centos.amd64 \
    -t amphora-image-build-amd64-centos


  # BEWARE!!!!! Without mounting /proc, the diskimage-builder fails to find mount points and deletes the host's /dev,
  # making the host unusable

#  # Create Ubuntu18 Amphora Image
#  docker run --privileged -v /dev:/dev -v /proc:/proc -v /mnt:/mnt \
#    -v $(pwd)/octavia/:/octavia -ti amphora-image-build-amd64-ubuntu
  
  # Create CentOS 8 Amphora image
  docker run --privileged -v /dev:/dev -v /proc:/proc -v ~/CODE/openstack/octavia/:/octavia \
    -ti amphora-image-build-amd64-centos
}


upload_amphora () {
  mv ~/CODE/openstack/octavia/diskimage-create/amphora-x64-haproxy.qcow2 /registry/images/amphora-x64-haproxy-centos8-fromArmGuy.qcow2
  
  # Switch to the octavia user and service project
  export OS_USERNAME=octavia
  export OS_PASSWORD=$(grep octavia_keystone_password /etc/kolla/passwords.yml | awk '{ print $2}')
  export OS_PROJECT_NAME=service
  export OS_TENANT_NAME=service
  
  openstack image create amphora-x64-haproxy.qcow2 \
    --container-format bare \
    --disk-format qcow2 \
    --private \
    --tag amphora \
    --file /registry/images/amphora-x64-haproxy-centos8-fromArmGuy.qcow2
  
#  # We can now delete the image file
#  rm -f octavia/diskimage-create/amphora-x64-haproxy.qcow2
}


patch_worker_for_userdata () {
  # Patch the user_data_config_drive_template
  [[ -d ~/CODE/openstack/octavia ]] || { mkdir -p  ~/CODE/openstack/ && cd  ~/CODE/openstack/ && git clone https://github.com/openstack/octavia; }
  cd ~/CODE/openstack/octavia
  git apply  $KOLLA_SETUP_DIR/../files/octavia-Fix-userdata-template.patch
  # For now just update the octavia-worker container, no need to restart it
  ssh_control_sync_as_user_these_hosts root octavia/common/jinja/templates/user_data_config_drive.template /tmp/user_data_config_drive.template "$CONTROL_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker cp /tmp/user_data_config_drive.template \
                   octavia_worker:/var/lib/kolla/venv/lib/python3.6/site-packages/octavia/common/jinja/templates/user_data_config_drive.template" "$CONTROL_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker cp /tmp/user_data_config_drive.template \
                   octavia_worker:/octavia-base-source/octavia-7.1.2.dev2/octavia/common/jinja/templates/user_data_config_drive.template" "$CONTROL_HOSTS"
}

setup_octavia_client () {
  pip3 install python-octaviaclient    || return 1
}


debug () {
  # Instances stuck in pending create cannot be deleted
  # Password: grep octavia_database_password /etc/kolla/passwords.yml
  docker exec -ti mariadb mysql -u octavia -p octavia
  update load_balancer set provisioning_status = 'ERROR' where provisioning_status = 'PENDING_CREATE';
  exit;
}



use_venv kolla-ansible
cat $SUDO_PASS_FILE | sudo -S ls > /dev/null    || return 1
setup_octavia_in_globals                       || fail_exit "setup_octavia_in_globals"
kolla-ansible octavia-certificates             || fail_exit "kolla-ansible octavia-certificates"

configure_octavia_net                          || fail_exit "configure_octavia_net"
setup_provider_net $PROVIDER_NETNAME $PROVIDER_VLAN_ID $PROVIDER_SUBNET $PROVIDER_ROUTER_IP $PROVIDER_SUBNET_START $PROVIDER_SUBNET_END  || fail_exit "setup_provider_net"
configure_octavia                              || fail_exit "configure_octavia"
deploy_octavia                                 || fail_exit "deploy_octavia"

#build_amphora                                  || fail_exit "build_amphora"
upload_amphora                                 || fail_exit "upload_amphora"
patch_worker_for_userdata                      || fail_exit "patch_worker_for_userdata"

setup_octavia_client                           || fail_exit "setup_octavia_client"

#debug                                          || fail_exit "debug"

[[ $SUDO_PASS_FILE == ~/.password ]]                || rm $SUDO_PASS_FILE
