#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )

# BAIL OUT IF USER SOURCES SCRIPT, INSTEAD OF RUNNING IT
if [ ! "${BASH_SOURCE[0]}" -ef "$0" ]; then
  echo "Do not source this script (exits will bail you...)."
  echo "Run it instead"
  return 1
fi

. ~/CODE/feralcoder/host_control/control_scripts.sh
. ~/CODE/venvs/kolla-ansible/bin/activate

ANSIBLE_CONTROLLER=dmb

fail_exit () {
  echo; echo "INSTALLATION FAILED AT STEP: $1"
  echo "Check the logs and try again.  Or just give up.  I don't care."
  exit 1
}



pip install python-openstackclient

kolla-ansible post-deploy
. /etc/kolla/admin-openrc.sh

XXX=~/CODE/venvs/kolla-ansible/share/kolla-ansible/init-runonce
[[ -f $XXX.orig ]] || cp $XXX $XXX.orig
cp $KOLLA_SETUP_DIR/../files/kolla-init-runonce $XXX
chmod 755 $XXX
$XXX

correct_compute_perms () {
  ssh_control_run_as_user_these_hosts root "docker exec -u root nova_compute mkdir -p /var/run/ceph/guests/ /var/log/qemu/; docker exec -u root nova_compute chown qemu:libvirt /var/run/ceph/guests /var/log/qemu/" "$COMPUTE_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker exec -u root nova_compute sed -i 's/ceph:x:167:$/ceph:x:167:qemu/g' /etc/group" "$COMPUTE_HOSTS"

  ssh_control_sync_as_user_these_hosts root /etc/kolla/config/nova/ceph.client.nova.keyring /etc/kolla/nova-compute/ "$COMPUTE_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker cp /etc/kolla/nova-compute/ceph.client.nova.keyring nova_compute:/etc/ceph/ceph.client.nova.keyring" "$COMPUTE_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker stop nova_compute; docker start nova_compute" "$COMPUTE_HOSTS"
}


# ADD THESE PROPERTIES TO IMAGES IN STACK:
#hw_scsi_model=virtio-scsi: add the virtio-scsi controller and get better performance and support for discard operation
#hw_disk_bus=scsi: connect every cinder block devices to that controller
#hw_qemu_guest_agent=yes: enable the QEMU guest agent
#os_require_quiesce=yes: send fs-freeze/thaw calls through the QEMU guest agent
