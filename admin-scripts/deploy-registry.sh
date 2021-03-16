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

echo; echo "INSTALLING YUM-UTILS and DOCKER.CE REPO"
ssh_control_run_as_user root "yum install -y yum-utils" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "(dnf repolist | grep docker) || yum-config-manager     --add-repo     https://download.docker.com/linux/centos/docker-ce.repo" $ANSIBLE_CONTROLLER

echo; echo "INSTALLING CONTAINERD AND DOCKER.CE, AND POKING HOLE IN FIREWALL"
#ssh_control_run_as_user root "dnf -y install https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm" $ANSIBLE_CONTROLLER
# Above may no longer be necessary
ssh_control_run_as_user root "firewall-cmd --zone=public --add-port=4000/tcp" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "firewall-cmd --permanent --zone=public --add-port=4000/tcp" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "dnf -y install docker-ce" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "systemctl enable --now docker" $ANSIBLE_CONTROLLER

echo; echo "PLACING docker-registry SERVICE FILES"
ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-registry-start.sh /usr/local/bin/docker-registry-start.sh $ANSIBLE_CONTROLLER
ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-registry-stop.sh /usr/local/bin/docker-registry-stop.sh $ANSIBLE_CONTROLLER
ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-registry.service /etc/systemd/system/docker-registry.service $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "chown root:root /usr/local/bin/docker-registry-start.sh; chmod 755 /usr/local/bin/docker-registry-start.sh" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "chown root:root /usr/local/bin/docker-registry-stop.sh; chmod 755 /usr/local/bin/docker-registry-stop.sh" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "chown root:root /etc/systemd/system/docker-registry.service; chmod 644 /etc/systemd/system/docker-registry.service" $ANSIBLE_CONTROLLER
ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-daemon.json /etc/docker/daemon.json $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "chown root:root /etc/docker/daemon.json; chmod 644 /etc/docker/daemon.json" $ANSIBLE_CONTROLLER

# NOW NOT NEEDED.  WHY???
#echo; echo "CONFIGURING SELINUX TO TOLERATE docker-registry"
#ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-registry.te /tmp/docker-registry.te $ANSIBLE_CONTROLLER
#ssh_control_run_as_user root "checkmodule -M  -m -o /tmp/docker-registry.mod /tmp/docker-registry.te" $ANSIBLE_CONTROLLER
#ssh_control_run_as_user root "semodule_package -o /tmp/docker-registry.pp  -m /tmp/docker-registry.mod" $ANSIBLE_CONTROLLER
#ssh_control_run_as_user root "semodule -i /tmp/docker-registry.pp" $ANSIBLE_CONTROLLER

echo; echo "ENABLING AND STARTING docker-registry"
ssh_control_run_as_user root "systemctl enable docker-registry" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "systemctl start docker-registry" $ANSIBLE_CONTROLLER


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
