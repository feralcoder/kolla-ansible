#!/bin/bash

[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

. ~/CODE/feralcoder/host_control/control_scripts.sh

last_octets () {
  for HOST in dmb kgn neo bmn lmn mtn str mrl gnd; do
    IP=`getent ahosts $HOST | awk '{print $1}' | tail -n 1`
    LAST_OCTET=`echo $IP | sed 's/192.168.127.//g'`
    echo $LAST_OCTET
  done
}

LAST_OCTETS=`last_octets $ALL_HOSTS | tr '\n' ' ' `

test_nets () {
  for NET_24 in 192.168.127 192.168.40 172.19.2 172.19.3 172.19.4 172.19.5; do
    ssh_control_run_as_user_these_hosts root "for HOST_8 in $LAST_OCTETS; do ping -c3 -t1 ${NET_24}.\$HOST_8 ; done" "dmb kgn neo bmn lmn mtn str mrl gnd"
  done
}

echo "$LAST_OCTETS"
test_nets

for i in $ALL_HOSTS; do ssh root@$i hostname; done
