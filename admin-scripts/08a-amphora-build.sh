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
  python3 ~/CODE/feralcoder/twilio-pager/pager.py "Fallen.  Can't get up.  Installation failed at $1."
  exit 1
}

create_amphora () {
  mkdir ~/amphora_cache
  cp $KOLLA_SETUP_DIR/../files/octavia-amphora-dockerfile ~/amphora_cache/Dockerfile
  (cd ~/amphora_cache ; docker build -t os .)
  docker run -it -v ~/amphora_cache:/lab --privileged os
}



create_amphora
ssh_control_sync_as_user root ~/amphora_cache/amphora-x64-haproxy.qcow2 /registry/images/ dmb
ssh_control_run_as_user root "cd /registry/images && qemu-img convert amphora-x64-haproxy.qcow2 amphora-x64-haproxy.img" dmb
ssh_control_run_as_user cliff ". ~/CODE/venvs/kolla-ansible/bin/activate && . /etc/kolla/admin-openrc.sh && openstack  image create --shared --disk-format raw --file /registry/images/amphora-x64-haproxy.img --min-disk 2 --min-ram 1024 --property hw_disk_bus=scsi --property hw_scsi_model=virtio-scsi --property os_distro=ubuntu --property os_version=18.04 'Octavia Amphora Haproxy - master' --tag amphora" dmb
