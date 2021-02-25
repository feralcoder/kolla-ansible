#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( dirname $KOLLA_SETUP_SOURCE )

ssh_control_run_as_user_these_hosts root "dnf -y erase buildah podman" "$ALL_HOSTS"
