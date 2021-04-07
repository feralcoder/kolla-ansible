#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )

. $KOLLA_SETUP_DIR/common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"
use_venv kolla-ansible            || fail_exit "use_venv kolla-ansible"

ANSIBLE_CONTROLLER=dmb



# ADD THESE PROPERTIES TO IMAGES IN STACK:
#hw_scsi_model=virtio-scsi: add the virtio-scsi controller and get better performance and support for discard operation
#hw_disk_bus=scsi: connect every cinder block devices to that controller
#hw_qemu_guest_agent=yes: enable the QEMU guest agent
#os_require_quiesce=yes: send fs-freeze/thaw calls through the QEMU guest agent

post_install_install () {
  pip install python-openstackclient   || return 1
  kolla-ansible post-deploy            || return 1
  . /etc/kolla/admin-openrc.sh         || return 1
}

setup_magnum () {
  OS_CODE=~/CODE/openstack             || return 1
  pip install python-magnumclient      || return 1
}


correct_compute_perms () {
  # Nova directory perms for ceph
  ssh_control_run_as_user_these_hosts root "docker exec -u root nova_compute mkdir -p /var/run/ceph/guests/ /var/log/qemu/; docker exec -u root nova_compute chown qemu:libvirt /var/run/ceph/guests /var/log/qemu/" "$COMPUTE_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker exec -u root nova_compute chmod 775 /var/run/ceph/guests /var/log/qemu/" "$COMPUTE_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker exec -u root nova_compute usermod -a -G ceph qemu; docker exec -u root nova_compute usermod -a -G ceph libvirt" "$COMPUTE_HOSTS"
}

place_and_run_init () {
  XXX=~/CODE/venvs/kolla-ansible/share/kolla-ansible/init-runonce
  [[ -f $XXX.orig ]] || cp $XXX $XXX.orig
  ( diff $XXX.orig  $KOLLA_SETUP_DIR/../files/kolla-init-runonce.orig ) || { echo "$XXX.orig has changed upstream!  Resolve."; return 1; }
  cp $KOLLA_SETUP_DIR/../files/kolla-init-runonce $XXX
  chmod 755 $XXX
  $XXX
  mv ~/KOLLA_SETUP_DIR/utility/cirros-0.5.1-x86_64-disk.img /registry/images
}


post_install_install       || fail_exit "post_install_install"
setup_magnum               || fail_exit "setup_magnum"
correct_compute_perms      || fail_exit "correct_compute_perms"
place_and_run_init         || fail_exit "place_and_run_init"


