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

ANSIBLE_CONTROLLER=dmb

fail_exit () {
  echo; echo "INSTALLATION FAILED AT STEP: $1"
  echo "Check the logs and try again.  Or just give up.  I don't care."
  exit 1
}




# ADD THESE PROPERTIES TO IMAGES IN STACK:
#hw_scsi_model=virtio-scsi: add the virtio-scsi controller and get better performance and support for discard operation
#hw_disk_bus=scsi: connect every cinder block devices to that controller
#hw_qemu_guest_agent=yes: enable the QEMU guest agent
#os_require_quiesce=yes: send fs-freeze/thaw calls through the QEMU guest agent



# SET DIRECTORY PERMS ON COMPUTE NODES FOR RBD CACHE AND ADMIN SOCKETS
# mkdir -p /var/run/ceph/guests/ /var/log/qemu/
# chown qemu:libvirtd /var/run/ceph/guests /var/log/qemu/
# (NOTE: check user:group qemu:libvirtd may vary!)

