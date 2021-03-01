#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( dirname $KOLLA_SETUP_SOURCE )

ANSIBLE_CONTROLLER=dmb


ssh_control_run_as_user root "yum install -y yum-utils" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "yum-config-manager     --add-repo     https://download.docker.com/linux/centos/docker-ce.repo" $ANSIBLE_CONTROLLER


ssh_control_run_as_user root "dnf -y install https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "dnf -y install docker-ce" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "systemctl disable firewalld; systemctl enable --now docker" $ANSIBLE_CONTROLLER

#
#ssh_control_run_as_user root "dnf -y erase buildah podman" $ANSIBLE_CONTROLLER
#ssh_control_run_as_user root "dnf -y install docker" $ANSIBLE_CONTROLLER
#

ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-registry.sh /root/docker-registry.sh $ANSIBLE_CONTROLLER
ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-registry.service /etc/systemd/system/docker-registry.service $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "chmod 644 /etc/systemd/system/docker-registry.service; systemctl enable docker-registry" $ANSIBLE_CONTROLLER
ssh_control_run_as_user root "/root/docker-registry.sh" $ANSIBLE_CONTROLLER
