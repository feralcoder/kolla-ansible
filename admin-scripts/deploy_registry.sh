#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( dirname $KOLLA_SETUP_SOURCE )

ANSIBLE_CONTROLLER=dmb


ssh_control_run_as_user root "yum install -y yum-utils" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "yum-config-manager     --add-repo     https://download.docker.com/linux/centos/docker-ce.repo" $ANSIBLE_CONTROLLER


ssh_control_run_as_user root "dnf -y install https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "dnf -y install docker-ce" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "systemctl disable firewalld; systemctl enable --now docker" $ANSIBLE_CONTROLLER

ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-registry.sh /root/docker-registry.sh $ANSIBLE_CONTROLLER
ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-registry.service /etc/systemd/system/docker-registry.service $ANSIBLE_CONTROLLER
ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-registry.te /tmp/docker-registry.te $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "chown root:root /root/docker-registry.sh; chmod 755 /root/docker-registry.sh" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "chown root:root /etc/systemd/system/docker-registry.service; chmod 644 /etc/systemd/system/docker-registry.service" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "systemctl enable docker-registry" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "checkmodule -M  -m -o /tmp/docker-registry.mod /tmp/docker-registry.te" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "semodule_package -o /tmp/docker-registry.pp  -m /tmp/docker-registry.mod" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "semodule -i /tmp/docker-registry.pp" $ANSIBLE_CONTROLLER

ssh_control_run_as_user root "systemctl start docker-registry" $ANSIBLE_CONTROLLER


# /tmp/docker-registry.te BUILT LIKE SO:
#TEST=fail
#while [[ $TEST == "fail" ]]; do
#  ausearch -c '(istry.sh)' --raw | audit2allow -m docker-registry >> /tmp/docker-registry.te
#  checkmodule -M  -m -o /tmp/docker-registry.mod /tmp/docker-registry.te
#  semodule_package -o docker-registry.pp  -m /tmp/docker-registry.mod
#  semodule -i docker-registry.pp
#  systemctl start docker-registry
#  [[ $? == 0 ]] && TEST=pass
#  ITER=$(($ITER+1))
#done
