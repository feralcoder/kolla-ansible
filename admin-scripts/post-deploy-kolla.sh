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




post_install_install () {
  pip install python-openstackclient
  kolla-ansible post-deploy
  . /etc/kolla/admin-openrc.sh
}

place_and_run_init () {
  XXX=~/CODE/venvs/kolla-ansible/share/kolla-ansible/init-runonce
  [[ -f $XXX.orig ]] || cp $XXX $XXX.orig
  cp $KOLLA_SETUP_DIR/../files/kolla-init-runonce $XXX
  chmod 755 $XXX
  $XXX
}

get_libvirt_user_uuid () {
  local USER=$1
  HOST=kgn
  GREPFILE=/tmp/grepuuid_$$
  echo '#!/bin/bash' > $GREPFILE
  echo "grep client.$USER /etc/libvirt/secrets/*" >> $GREPFILE && chmod 755 $GREPFILE
  ssh_control_sync_as_user root $GREPFILE $GREPFILE $HOST >/dev/null 2>&1
  ssh_control_run_as_user root "docker cp $GREPFILE ${USER}_libvirt:$GREPFILE" $HOST >/dev/null 2>&1
  UUID=`ssh_control_run_as_user root "docker exec ${USER}_libvirt $GREPFILE" $HOST | grep client.${USER} | awk -F'/' '{print $5}' | awk -F'.' '{print $1}'`
  echo $UUID
}

get_user_secret () {
  local USER=$1
  KEY=`grep key /etc/ceph/ceph.client.$USER.keyring | awk -F'=' '{print $2}' | sed 's/ //g'`
  echo $KEY
}

correct_compute_perms () {
  # Nova directory perms for ceph
  ssh_control_run_as_user_these_hosts root "docker exec -u root nova_compute mkdir -p /var/run/ceph/guests/ /var/log/qemu/; docker exec -u root nova_compute chown qemu:libvirt /var/run/ceph/guests /var/log/qemu/" "$COMPUTE_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker exec -u root nova_compute chmod 775 /var/run/ceph/guests /var/log/qemu/" "$COMPUTE_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker exec -u root nova_compute usermod -a -G ceph qemu; docker exec -u root nova_compute usermod -a -G ceph libvirt" "$COMPUTE_HOSTS"

  # WTF.  Nova user has incorrect key set up in libvirt.
  UUID_FILE=`get_libvirt_user_uuid nova`.base64
  echo `get_user_secret nova` > /tmp/$UUID_FILE
  ssh_control_sync_as_user_these_hosts root /tmp/$UUID_FILE /tmp/$UUID_FILE "$COMPUTE_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker cp /tmp/$UUID_FILE nova_libvirt:/etc/libvirt/secrets/$UUID_FILE" "$COMPUTE_HOSTS"
  ssh_control_run_as_user_these_hosts root "rm /tmp/$UUID_FILE" "$COMPUTE_HOSTS"

  # Nova client key wasn't placed for nova-compute and nova-libvirt
  ssh_control_sync_as_user_these_hosts root /etc/kolla/config/nova/ceph.client.nova.keyring /etc/kolla/nova-compute/ "$COMPUTE_HOSTS"
  ssh_control_sync_as_user_these_hosts root /etc/kolla/config/nova/ceph.client.nova.keyring /etc/kolla/nova-libvirt/ "$COMPUTE_HOSTS"
  ssh_control_sync_as_user_these_hosts root /etc/kolla/config/nova/ceph.client.cinder.keyring /etc/kolla/nova-libvirt/ "$COMPUTE_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker cp /etc/kolla/nova-compute/ceph.client.nova.keyring nova_compute:/etc/ceph/ceph.client.nova.keyring" "$COMPUTE_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker cp /etc/kolla/nova-libvirt/ceph.client.nova.keyring nova_libvirt:/etc/ceph/ceph.client.nova.keyring" "$COMPUTE_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker cp /etc/kolla/nova-libvirt/ceph.client.cinder.keyring nova_libvirt:/etc/ceph/ceph.client.cinder.keyring" "$COMPUTE_HOSTS"
  ssh_control_run_as_user_these_hosts root "docker stop nova_compute nova_libvirt; docker start nova_compute nova_libvirt" "$COMPUTE_HOSTS"
}

post_install_install
place_and_run_init
correct_compute_perms

# ADD THESE PROPERTIES TO IMAGES IN STACK:
#hw_scsi_model=virtio-scsi: add the virtio-scsi controller and get better performance and support for discard operation
#hw_disk_bus=scsi: connect every cinder block devices to that controller
#hw_qemu_guest_agent=yes: enable the QEMU guest agent
#os_require_quiesce=yes: send fs-freeze/thaw calls through the QEMU guest agent
