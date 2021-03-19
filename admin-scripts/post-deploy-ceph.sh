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
  CEPH_MON=`echo "$CEPH_MON_HOSTS" | tr ' ' '\n' | head -n 1`                                                                                     || return 1
  MON_CONTAINER=`ssh_control_run_as_user root "docker container list" $CEPH_MON | grep ' ceph-mon-' | awk '{print $1}'`                           || return 1

  ( grep auth_cluster_required /etc/ceph/ceph.conf ) || ( echo "mon initial members = strange-api,merlin-api,gandalf-api" && echo "auth_cluster_required = cephx" && echo "auth_service_required = cephx" && echo "auth_client_required = cephx" ) | sudo tee -a /etc/ceph/ceph.conf    || return 1

  # CLIENT AUTH DETAILS HERE:
  # https://docs.ceph.com/en/latest/rbd/rbd-openstack/

  # CLIENT GLANCE
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph osd pool create images 32" $CEPH_MON                                              || return 1
  ssh_control_run_as_user root "docker exec $MON_CONTAINER rbd pool init images" $CEPH_MON                                              || return 1
#  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.glance mon 'allow r' osd 'allow class-read object_prefix rdb_children, allow rwx pool=images' -o /etc/ceph/ceph.client.glance.keyring" $CEPH_MON    || return 1
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.glance mon 'profile rbd' osd 'profile rbd pool=images' mgr 'profile rbd pool=images'" $CEPH_MON    || return 1
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.glance -o /etc/ceph/ceph.client.glance.keyring" $CEPH_MON    || return 1
  ssh_control_run_as_user cliff "ssh_control_sync_as_user root /etc/ceph/ceph.client.glance.keyring /etc/ceph/ $ANSIBLE_CONTROLLER" $CEPH_MON     || return 1

  # CLIENT CINDER
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph osd pool create volumes 32" $CEPH_MON                                             || return 1
  ssh_control_run_as_user root "docker exec $MON_CONTAINER rbd pool init volumes" $CEPH_MON                                             || return 1
#  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.cinder mon 'allow r' osd 'allow class-read object_prefix rdb_children, allow rwx pool=volumes' -o /etc/ceph/ceph.client.cinder.keyring" $CEPH_MON    || return 1
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.cinder mon 'profile rbd' osd 'profile rbd pool=volumes, profile rbd pool=vms, profile rbd-read-only pool=images' mgr 'profile rbd pool=volumes, profile rbd pool=vms'" $CEPH_MON    || return 1
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.cinder -o /etc/ceph/ceph.client.cinder.keyring" $CEPH_MON    || return 1
  ssh_control_run_as_user cliff "ssh_control_sync_as_user root /etc/ceph/ceph.client.cinder.keyring /etc/ceph/ $ANSIBLE_CONTROLLER" $CEPH_MON     || return 1

  # CLIENT CINDER-BACKUP
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph osd pool create backups 32" $CEPH_MON                                             || return 1
  ssh_control_run_as_user root "docker exec $MON_CONTAINER rbd pool init backups" $CEPH_MON                                             || return 1
#  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.cinder-backup mon 'allow r' osd 'allow class-read object_prefix rdb_children, allow rwx pool=backups' -o /etc/ceph/ceph.client.cinder-backup.keyring" $CEPH_MON    || return 1
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.cinder-backup mon 'profile rbd' osd 'profile rbd pool=backups' mgr 'profile rbd pool=backups'" $CEPH_MON    || return 1
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.cinder-backup -o /etc/ceph/ceph.client.cinder-backup.keyring" $CEPH_MON    || return 1
  ssh_control_run_as_user cliff "ssh_control_sync_as_user root /etc/ceph/ceph.client.cinder-backup.keyring /etc/ceph/ $ANSIBLE_CONTROLLER" $CEPH_MON    || return 1

  # CLIENT NOVA
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph osd pool create vms 32" $CEPH_MON                                                 || return 1
  ssh_control_run_as_user root "docker exec $MON_CONTAINER rbd pool init vms" $CEPH_MON                                                 || return 1
#  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.nova mon 'allow r' osd 'allow class-read object_prefix rdb_children, allow rwx pool=vms' -o /etc/ceph/ceph.client.nova.keyring" $CEPH_MON    || return 1
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.nova mon 'profile rbd' osd 'profile rbd pool=volumes, profile rbd pool=vms, profile rbd-read-only pool=images' mgr 'profile rbd pool=volumes, profile rbd pool=vms'" $CEPH_MON    || return 1
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.nova -o /etc/ceph/ceph.client.nova.keyring" $CEPH_MON    || return 1
  ssh_control_run_as_user cliff "ssh_control_sync_as_user root /etc/ceph/ceph.client.nova.keyring /etc/ceph/ $ANSIBLE_CONTROLLER" $CEPH_MON       || return 1

  # CLIENT GNOCCHI
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph osd pool create metrics 32" $CEPH_MON                                             || return 1
#  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.gnocchi mon 'allow r' osd 'allow class-read object_prefix rdb_children, allow rwx pool=metrics' -o /etc/ceph/ceph.client.gnocchi.keyring" $CEPH_MON    || return 1
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.gnocchi mon 'allow r' osd 'allow class-read object_prefix rdb_children, allow rwx pool=metrics'" $CEPH_MON    || return 1
  ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph auth get-or-create client.gnocchi -o /etc/ceph/ceph.client.gnocchi.keyring" $CEPH_MON    || return 1
  ssh_control_run_as_user cliff "ssh_control_sync_as_user root /etc/ceph/ceph.client.gnocchi.keyring /etc/ceph/ $ANSIBLE_CONTROLLER" $CEPH_MON    || return 1

  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null    || return 1
  sudo mkdir -p /etc/kolla/config/cinder/cinder-backup/ > /dev/null 2>&1    || return 1
  sudo mkdir -p /etc/kolla/config/cinder/cinder-volume/ > /dev/null 2>&1    || return 1
  sudo mkdir -p /etc/kolla/config/cinder/ > /dev/null 2>&1                  || return 1
  sudo mkdir -p /etc/kolla/config/glance/ > /dev/null 2>&1                  || return 1
  sudo mkdir -p /etc/kolla/config/nova/ > /dev/null 2>&1                    || return 1
  sudo mkdir -p /etc/kolla/config/gnocchi/ > /dev/null 2>&1                 || return 1
  sudo cp /etc/ceph/ceph.client.glance.keyring /etc/kolla/config/glance/                  || return 1
  sudo cp /etc/ceph/ceph.client.cinder-backup.keyring /etc/kolla/config/cinder/cinder-backup/    || return 1
  sudo cp /etc/ceph/ceph.client.cinder.keyring /etc/kolla/config/cinder/cinder-backup/    || return 1
  sudo cp /etc/ceph/ceph.client.cinder.keyring /etc/kolla/config/cinder/cinder-volume/    || return 1
  sudo cp /etc/ceph/ceph.client.cinder.keyring /etc/kolla/config/nova/                    || return 1
  sudo cp /etc/ceph/ceph.client.nova.keyring /etc/kolla/config/nova/                      || return 1
  sudo cp /etc/ceph/ceph.client.gnocchi.keyring /etc/kolla/config/gnocchi/                || return 1
  sudo cp $KOLLA_SETUP_DIR/../files/ceph-client-cinder-backup.conf /etc/kolla/config/cinder/cinder-backup.conf    || return 1
  sudo cp $KOLLA_SETUP_DIR/../files/ceph-client-cinder-volume.conf /etc/kolla/config/cinder/cinder-volume.conf    || return 1
  sudo cp $KOLLA_SETUP_DIR/../files/ceph-client-glance-api.conf /etc/kolla/config/glance/glance-api.conf          || return 1
  sudo cp $KOLLA_SETUP_DIR/../files/ceph-client-nova-compute.conf /etc/kolla/config/nova/nova-compute.conf        || return 1
  sudo cp $KOLLA_SETUP_DIR/../files/ceph-client-gnocchi.conf /etc/kolla/config/gnocchi/gnocchi.conf               || return 1
  sudo cp /etc/ceph/ceph.conf /etc/kolla/config/cinder/    || return 1
  sudo cp /etc/ceph/ceph.conf /etc/kolla/config/glance/    || return 1
  sudo cp /etc/ceph/ceph.conf /etc/kolla/config/nova/      || return 1
  sudo cp /etc/ceph/ceph.conf /etc/kolla/config/gnocchi/   || return 1
  cat $KOLLA_SETUP_DIR/../files/ceph-nova-ceph-conf-addl.conf >> /etc/kolla/config/nova/ceph.conf  || return 1
}




SUDO_PASS_FILE=`admin_control_get_sudo_password`    || fail_exit "admin_control_get_sudo_password"
set_up_ceph_volumes_and_users                       || fail_exit "set_up_ceph_volumes_and_users"

[[ $SUDO_PASS_FILE == ~/.password ]]                || rm $SUDO_PASS_FILE
