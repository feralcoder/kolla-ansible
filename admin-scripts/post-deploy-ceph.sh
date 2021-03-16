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


set_up_ceph_volumes_and_users () {
  CEPH_MON=`echo "$CEPH_MON_HOSTS" | tr ' ' '\n' | head -n 1`
  MON_CONTAINER=`ssh_control_run_as_user root "docker container list" $CEPH_MON | grep ' ceph-mon-' | awk '{print $1}'`

  ( grep auth_cluster_required /etc/ceph/ceph.conf ) || ( echo "mon initial members = strange-api,merlin-api,gandalf-api" && echo "auth_cluster_required = cephx" && echo "auth_service_required = cephx" && echo "auth_client_required = cephx" ) | sudo tee -a /etc/ceph/ceph.conf

  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph osd pool create images 32" $CEPH_MON
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.glance mon 'allow r' osd 'allow class-read object_prefix rdb_children, allow rwx pool=images' -o /etc/ceph/ceph.client.glance.keyring" $CEPH_MON
  ssh_control_run_as_user cliff "ssh_control_sync_as_user root /etc/ceph/ceph.client.glance.keyring /etc/ceph/ $ANSIBLE_CONTROLLER" $CEPH_MON

  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph osd pool create volumes 32" $CEPH_MON
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.cinder mon 'allow r' osd 'allow class-read object_prefix rdb_children, allow rwx pool=volumes' -o /etc/ceph/ceph.client.cinder.keyring" $CEPH_MON
  ssh_control_run_as_user cliff "ssh_control_sync_as_user root /etc/ceph/ceph.client.cinder.keyring /etc/ceph/ $ANSIBLE_CONTROLLER" $CEPH_MON

  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph osd pool create backups 32" $CEPH_MON
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.cinder-backup mon 'allow r' osd 'allow class-read object_prefix rdb_children, allow rwx pool=backups' -o /etc/ceph/ceph.client.cinder-backup.keyring" $CEPH_MON
  ssh_control_run_as_user cliff "ssh_control_sync_as_user root /etc/ceph/ceph.client.cinder-backup.keyring /etc/ceph/ $ANSIBLE_CONTROLLER" $CEPH_MON

  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph osd pool create vms 32" $CEPH_MON
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.nova mon 'allow r' osd 'allow class-read object_prefix rdb_children, allow rwx pool=vms' -o /etc/ceph/ceph.client.nova.keyring" $CEPH_MON
  ssh_control_run_as_user cliff "ssh_control_sync_as_user root /etc/ceph/ceph.client.nova.keyring /etc/ceph/ $ANSIBLE_CONTROLLER" $CEPH_MON

  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph osd pool create metrics 32" $CEPH_MON
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.gnocchi mon 'allow r' osd 'allow class-read object_prefix rdb_children, allow rwx pool=metrics' -o /etc/ceph/ceph.client.gnocchi.keyring" $CEPH_MON
  ssh_control_run_as_user cliff "ssh_control_sync_as_user root /etc/ceph/ceph.client.gnocchi.keyring /etc/ceph/ $ANSIBLE_CONTROLLER" $CEPH_MON

  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo mkdir -p /etc/kolla/config/cinder/cinder-backup/ > /dev/null 2>&1
  sudo mkdir -p /etc/kolla/config/cinder/cinder-volume/ > /dev/null 2>&1
  sudo mkdir -p /etc/kolla/config/cinder/ > /dev/null 2>&1
  sudo mkdir -p /etc/kolla/config/glance/ > /dev/null 2>&1
  sudo mkdir -p /etc/kolla/config/nova/ > /dev/null 2>&1
  sudo mkdir -p /etc/kolla/config/gnocchi/ > /dev/null 2>&1
  sudo cp /etc/ceph/ceph.client.glance.keyring /etc/kolla/config/glance/
  sudo cp /etc/ceph/ceph.client.cinder-backup.keyring /etc/kolla/config/cinder/cinder-backup/
  sudo cp /etc/ceph/ceph.client.cinder.keyring /etc/kolla/config/cinder/cinder-backup/
  sudo cp /etc/ceph/ceph.client.cinder.keyring /etc/kolla/config/cinder/cinder-volume/
  sudo cp /etc/ceph/ceph.client.cinder.keyring /etc/kolla/config/nova/
  sudo cp /etc/ceph/ceph.client.nova.keyring /etc/kolla/config/nova/
  sudo cp /etc/ceph/ceph.client.gnocchi.keyring /etc/kolla/config/gnocchi/
  sudo cp $KOLLA_SETUP_DIR/../files/ceph-cinder-backup.conf /etc/kolla/config/cinder/cinder-backup.conf
  sudo cp $KOLLA_SETUP_DIR/../files/ceph-cinder-volume.conf /etc/kolla/config/cinder/cinder-volume.conf
  sudo cp $KOLLA_SETUP_DIR/../files/ceph-glance-api.conf /etc/kolla/config/glance/glance-api.conf
  sudo cp $KOLLA_SETUP_DIR/../files/ceph-nova-compute.conf /etc/kolla/config/nova/nova-compute.conf
  sudo cp $KOLLA_SETUP_DIR/../files/ceph-gnocchi.conf /etc/kolla/config/gnocchi/gnocchi.conf
  sudo cp /etc/ceph/ceph.conf /etc/kolla/config/cinder/
  sudo cp /etc/ceph/ceph.conf /etc/kolla/config/glance/
  sudo cp /etc/ceph/ceph.conf /etc/kolla/config/nova/
  sudo cp /etc/ceph/ceph.conf /etc/kolla/config/gnocchi/
}




SUDO_PASS_FILE=`admin_control_get_sudo_password`
set_up_ceph_volumes_and_users

[[ $SUDO_PASS_FILE == ~/.password ]] || rm $SUDO_PASS_FILE
