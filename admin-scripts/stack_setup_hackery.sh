#!/bin/bash


#ssh_control_run_as_user_these_hosts root "dnf -y install python3-dnf-plugin-versionlock" "$ALL_HOSTS"
#ssh_control_run_as_user_these_hosts root "dnf versionlock exclude podman-0:2.*" "$ALL_HOSTS"
#dnf versionlock exclude containerd.io-1.4.3

ssh_control_run_as_user_these_hosts root "dnf -y erase buildah podman" "$ALL_HOSTS"
