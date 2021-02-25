#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( dirname $KOLLA_SETUP_SOURCE )


ssh_control_run_as_user root "sudo yum install -y yum-utils" dmb
ssh_control_run_as_user root "sudo yum-config-manager     --add-repo     https://download.docker.com/linux/centos/docker-ce.repo" dmb


ssh_control_run_as_user root "dnf -y install https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm" dmb
ssh_control_run_as_user root "dnf -y install docker-ce" dmb
ssh_control_run_as_user root "systemctl disable firewalld; systemctl enable --now docker" dmb

#
#ssh_control_run_as_user root "dnf -y erase buildah podman" dmb
#ssh_control_run_as_user root "dnf -y install docker" dmb
#

ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-registry.sh /root/docker-registry.sh dmb
ssh_control_sync_as_user root $KOLLA_SETUP_DIR/../files/docker-registry.service /etc/systemd/system/docker-registry.service dmb
ssh_control_run_as_user root "chmod 644 /etc/systemd/system/docker-registry.service; systemctl enable docker-registry" dmb
ssh_control_run_as_user root "/root/docker-registry.sh" dmb
