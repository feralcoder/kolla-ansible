#!/bin/bash

THESE_HOSTS="$ALL_HOSTS"
#THESE_HOSTS="mtn lmn bmn kgn neo str mrl gnd dmb"
ssh_control_sync_as_user_these_hosts root setup_host_bonds.sh /root/setup_host_bonds.sh "$THESE_HOSTS"
ssh_control_run_as_user_these_hosts root "nohup /root/setup_host_bonds.sh &" "$THESE_HOSTS"
