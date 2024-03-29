#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )

. $KOLLA_SETUP_DIR/common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"
use_venv kolla-ansible            || fail_exit "use_venv kolla-ansible"

ANSIBLE_CONTROLLER=dmb


install_packages () {
  echo; echo "INSTALLING YUM-UTILS and DOCKER.CE REPO"
  ssh_control_run_as_user root "yum install -y yum-utils" $ANSIBLE_CONTROLLER                || return 1
  echo; echo "INSTALLING CONTAINERD AND DOCKER.CE"
  ssh_control_run_as_user root "(dnf repolist | grep docker) || yum-config-manager     --add-repo     https://download.docker.com/linux/centos/docker-ce.repo" $ANSIBLE_CONTROLLER   || return 1
  ssh_control_run_as_user root "dnf -y install docker-ce" $ANSIBLE_CONTROLLER                || return 1
  ssh_control_run_as_user root "mkdir /etc/docker" $ANSIBLE_CONTROLLER                       || return 1
  ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-daemon.json /etc/docker/daemon.json $ANSIBLE_CONTROLLER                 || return 1
  ssh_control_run_as_user root "systemctl enable --now docker" $ANSIBLE_CONTROLLER           || return 1
}

democratize_docker () {
  ssh_control_run_as_user_these_hosts root "usermod -a -G docker cliff" "$ANSIBLE_CONTROLLER"                                         || return 1
}

disable_firewall () {
  echo; echo "DISABLE FIREWALLD"
  ssh_control_run_as_user_these_hosts root "systemctl disable firewalld" "$STACK_HOSTS"                    || return 1
  ssh_control_run_as_user_these_hosts root "systemctl stop firewalld" "$STACK_HOSTS"                       || return 1
}

set_up_docker_registry_service () {
  echo; echo "PLACING docker-local-registry SERVICE FILES"
  ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-local-registry-start.sh /usr/local/bin/docker-local-registry-start.sh $ANSIBLE_CONTROLLER                             || return 1
  ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-local-registry-stop.sh /usr/local/bin/docker-local-registry-stop.sh $ANSIBLE_CONTROLLER                               || return 1
  ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-local-registry.service /etc/systemd/system/docker-local-registry.service $ANSIBLE_CONTROLLER                          || return 1
  ssh_control_run_as_user root "chown root:root /usr/local/bin/docker-local-registry-start.sh; chmod 755 /usr/local/bin/docker-local-registry-start.sh" $ANSIBLE_CONTROLLER            || return 1
  ssh_control_run_as_user root "chown root:root /usr/local/bin/docker-local-registry-stop.sh; chmod 755 /usr/local/bin/docker-local-registry-stop.sh" $ANSIBLE_CONTROLLER              || return 1
  ssh_control_run_as_user root "chown root:root /etc/systemd/system/docker-local-registry.service; chmod 644 /etc/systemd/system/docker-local-registry.service" $ANSIBLE_CONTROLLER    || return 1

  echo; echo "ENABLING AND STARTING docker-local-registry"
  ssh_control_run_as_user root "systemctl enable docker-local-registry" $ANSIBLE_CONTROLLER   || fail_exit "start docker-local-registry"
  ssh_control_run_as_user root "systemctl start docker-local-registry" $ANSIBLE_CONTROLLER    || fail_exit "start docker-local-registry"

  echo; echo "PLACING docker-pullthru-registry SERVICE FILES"
  ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-pullthru-registry-start.sh /usr/local/bin/docker-pullthru-registry-start.sh $ANSIBLE_CONTROLLER                             || return 1
  ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-pullthru-registry-stop.sh /usr/local/bin/docker-pullthru-registry-stop.sh $ANSIBLE_CONTROLLER                               || return 1
  ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-pullthru-registry.service /etc/systemd/system/docker-pullthru-registry.service $ANSIBLE_CONTROLLER                          || return 1
  ssh_control_run_as_user root "chown root:root /usr/local/bin/docker-pullthru-registry-start.sh; chmod 755 /usr/local/bin/docker-pullthru-registry-start.sh" $ANSIBLE_CONTROLLER            || return 1
  ssh_control_run_as_user root "chown root:root /usr/local/bin/docker-pullthru-registry-stop.sh; chmod 755 /usr/local/bin/docker-pullthru-registry-stop.sh" $ANSIBLE_CONTROLLER              || return 1
  ssh_control_run_as_user root "chown root:root /etc/systemd/system/docker-pullthru-registry.service; chmod 644 /etc/systemd/system/docker-pullthru-registry.service" $ANSIBLE_CONTROLLER    || return 1

  echo; echo "ENABLING AND STARTING docker-pullthru-registry"
  ssh_control_run_as_user root "systemctl enable docker-pullthru-registry" $ANSIBLE_CONTROLLER   || fail_exit "start docker-pullthru-registry"
  ssh_control_run_as_user root "systemctl start docker-pullthru-registry" $ANSIBLE_CONTROLLER    || fail_exit "start docker-pullthru-registry"
}


# NOW NOT NEEDED.  WHY???
#echo; echo "CONFIGURING SELINUX TO TOLERATE docker-registry"
#ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-registry.te /tmp/docker-registry.te $ANSIBLE_CONTROLLER
#ssh_control_run_as_user root "checkmodule -M  -m -o /tmp/docker-registry.mod /tmp/docker-registry.te" $ANSIBLE_CONTROLLER
#ssh_control_run_as_user root "semodule_package -o /tmp/docker-registry.pp  -m /tmp/docker-registry.mod" $ANSIBLE_CONTROLLER
#ssh_control_run_as_user root "semodule -i /tmp/docker-registry.pp" $ANSIBLE_CONTROLLER



#echo; echo "CONFIGURING DOCKER TO USE OUR LOCAL (INSECURE) MIRROR"
#ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-daemon.json /etc/docker/daemon.json $ANSIBLE_CONTROLLER
#ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-feralcoder-registry.conf /usr/lib/systemd/system/docker.service.d/feralcoder-registry.conf $ANSIBLE_CONTROLLER
#ssh_control_run_as_user root "chown root:root /etc/docker/daemon.json; chmod 644 /etc/docker/daemon.json" $ANSIBLE_CONTROLLER
#ssh_control_run_as_user root "chown root:root /usr/lib/systemd/system/docker.service.d/feralcoder-registry.conf; chmod 644 /usr/lib/systemd/system/docker.service.d/feralcoder-registry.conf" $ANSIBLE_CONTROLLER
#ssh_control_run_as_user root "systemctl daemon-reload" $ANSIBLE_CONTROLLER
#ssh_control_run_as_user root "systemctl restart docker" $ANSIBLE_CONTROLLER


# /tmp/docker-registry.te BUILT LIKE SO:
#TEST=fail
#while [[ $TEST == "fail" ]]; do
#  ausearch -c '(istry.sh)' --raw | audit2allow -m docker-registry > /tmp/docker-registry.te
#  checkmodule -M  -m -o /tmp/docker-registry.mod /tmp/docker-registry.te
#  semodule_package -o docker-registry.pp  -m /tmp/docker-registry.mod
#  semodule -i docker-registry.pp
#  systemctl start docker-registry
#  [[ $? == 0 ]] && TEST=pass
#  ITER=$(($ITER+1))
#done



install_packages               || fail_exit "install_packages"
democratize_docker             || fail_exit "democratize_docker"
disable_firewall               || fail_exit "disable_firewall"
set_up_docker_registry_service || fail_exit "set_up_docker_registry_service"

