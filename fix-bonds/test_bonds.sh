#!/bin/bash


last_octets () {
  for HOST in kgn neo bmn lmn mtn str mrl gnd; do
    IP=`getent ahosts $HOST | awk '{print $1}' | tail -n 1`
    LAST_OCTET=`echo $IP | sed 's/192.168.127.//g'`
    echo $LAST_OCTET
  done
}

LAST_OCTETS=`last_octets $ALL_HOSTS | tr '\n' ' ' `
echo "$LAST_OCTETS"

test_nets () {
  for NET_24 in 192.168.127 192.168.40 172.16.0 172.17.0 172.18.0 172.19.0; do
    ssh_control_run_as_user_these_hosts root "for HOST_8 in $LAST_OCTETS; do ping -c3 -t1 ${NET_24}.\$HOST_8 ; done" "kgn neo bmn lmn mtn str mrl gnd"
  done
}
