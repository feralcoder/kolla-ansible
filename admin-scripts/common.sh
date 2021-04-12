#!/bin/bash

source_host_control_scripts () {
  . ~/CODE/feralcoder/host_control/control_scripts.sh
}

fail_exit () {
  echo; echo "FAILURE, EXITING: $1"
  python3 ~/CODE/feralcoder/twilio-pager/pager.py "KOLLA-ANSIBLE FAILURE, EXITING: $1"
  exit 1
}

test_sudo () {
  sudo -K
  if [[ $SUDO_PASS_FILE == "" ]]; then
    echo "SUDO_PASS_FILE is undefined!"
    return 1
  fi
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null 2>&1
}

new_venv () {
  local VENV=$1
  [[ $VENV != "" ]] || { echo "No VENV supllied!"; return 1; }
  mkdir -p ~/CODE/venvs/$VENV &&
  python3 -m venv ~/CODE/venvs/$VENV
}

use_venv () {
  local VENV=$1
  [[ $VENV != "" ]] || { echo "No VENV supllied!"; return 1; }
  source ~/CODE/venvs/$VENV/bin/activate
}




# Configure setup_provider_net like so:
#configure_provider_net () {
#  PROVIDER_SUBNET=172.30.1.0/24
#  PROVIDER_SUBNET_START=172.30.1.10
#  PROVIDER_SUBNET_END=172.30.1.254
#  PROVIDER_ROUTER_IP=172.30.1.241/24
#  PROVIDER_VIRTROUTER_IP=172.30.1.1/24
#  PROVIDER_VLAN_ID=201
#  PROVIDER_NETNAME=pubnet1
#}

setup_provider_net () {
  local PROVIDER_NETNAME=$1 PROVIDER_VLAN_ID=$2 PROVIDER_SUBNET=$3 PROVIDER_ROUTER_IP=$4 PROVIDER_SUBNET_START=$5 PROVIDER_SUBNET_END=$6
  ssh_control_sync_as_user_these_hosts root ~/CODE/feralcoder/kolla-ansible/files/kolla-veth-XXX.sh /usr/local/bin/veth-$PROVIDER_NETNAME.sh "$CONTROL_HOSTS"  || return 1
  ssh_control_run_as_user_these_hosts root "chmod 744 /usr/local/bin/veth-$PROVIDER_NETNAME.sh" "$CONTROL_HOSTS"  || return 1

  ssh_control_sync_as_user_these_hosts root ~/CODE/feralcoder/kolla-ansible/files/kolla-veth-XXX.service /etc/systemd/system/veth-$PROVIDER_NETNAME.service "$CONTROL_HOSTS"  || return 1
  ssh_control_run_as_user_these_hosts root "chmod 644 /etc/systemd/system/veth-$PROVIDER_NETNAME.service" "$CONTROL_HOSTS"  || return 1
  
  for HOST in $CONTROL_HOSTS; do
    LAST_OCTET=`ssh_control_run_as_user root "ip addr" $HOST | grep 192.168.127 | grep inet | awk '{print $2}' | awk -F'/' '{print $1}' | awk -F'.' '{print $4}'`  || return 1
    ssh_control_run_as_user root "sed -i 's|__IP__|172.30.1.$LAST_OCTET/24|g' /usr/local/bin/veth-$PROVIDER_NETNAME.sh" $HOST  || return 1
    ssh_control_run_as_user root "sed -i 's|__NETNAME__|$PROVIDER_NETNAME|g' /usr/local/bin/veth-$PROVIDER_NETNAME.sh" $HOST  || return 1
    ssh_control_run_as_user root "sed -i 's|__NETNAME__|$PROVIDER_NETNAME|g' /etc/systemd/system/veth-$PROVIDER_NETNAME.service" $HOST  || return 1
  done

  ssh_control_run_as_user_these_hosts root "systemctl daemon-reload" "$CONTROL_HOSTS"  || return 1
  ssh_control_run_as_user_these_hosts root "systemctl disable veth-$PROVIDER_NETNAME.service" "$CONTROL_HOSTS"  || return 1
  ssh_control_run_as_user_these_hosts root "systemctl stop veth-$PROVIDER_NETNAME.service" "$CONTROL_HOSTS"  || return 1
  ssh_control_run_as_user_these_hosts root "systemctl enable veth-$PROVIDER_NETNAME.service" "$CONTROL_HOSTS"  || return 1
  ssh_control_run_as_user_these_hosts root "systemctl start veth-$PROVIDER_NETNAME.service" "$CONTROL_HOSTS"  || return 1
  
  ssh_control_run_as_user_these_hosts root "docker exec openvswitch_vswitchd ovs-vsctl --may-exist  add-port \
                br-ex v-$PROVIDER_NETNAME-vlan tag=$PROVIDER_VLAN_ID" "$CONTROL_HOSTS"  || return 1
  echo "previous command may error on success..."
}
