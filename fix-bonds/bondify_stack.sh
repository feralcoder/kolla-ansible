#!/bin/bash


CTL_SERVER_BONDS="kgn:eno1:bond1 neo:eno1:bond1 bmn:eno1:bond1 lmn:eno1:bond1 mtn:eno1:bond1 str:eno1:bond1 mrl:enp2s0f0:bond1 gnd:enp2s0f0:bond1"
EXT_SERVER_BONDS="kgn:eno2:bond2 neo:eno2:bond2 bmn:eno2:bond2 lmn:eno2:bond2 mtn:eno2:bond2 str:eno2:bond2 mrl:enp2s0f1:bond2 gnd:enp2s0f1:bond2"
API_SERVER_BONDS="kgn:eno3:bond3 neo:eno3:bond3 bmn:eno3:bond3 lmn:eno3:bond3 mtn:eno3:bond3 str:eno3:bond3 mrl:enp2s0f2:bond3 gnd:enp2s0f2:bond3"
STR_SERVER_BONDS="kgn:eno4:bond4 neo:eno4:bond4 bmn:eno4:bond4 lmn:eno4:bond4 mtn:eno4:bond4 str:eno4:bond4 mrl:enp2s0f3:bond4 gnd:enp2s0f3:bond4"
STM_SERVER_BONDS="kgn:ens5f0:bond5 neo:ens5f0:bond5 bmn:ens5f0:bond5 lmn:ens5f0:bond5 mtn:ens5f0:bond5 str:eno5:bond5 mrl:enp2s0f4:bond5 gnd:enp2s0f4:bond5"
TNT_SERVER_BONDS="kgn:ens5f1:bond6 neo:ens5f1:bond6 bmn:ens5f1:bond6 lmn:ens5f1:bond6 mtn:ens5f1:bond6 str:eno6:bond6 mrl:enp2s0f5:bond6 gnd:enp2s0f5:bond6"

#for SERVER_BOND in $CTL_SERVER_BONDS $EXT_SERVER_BONDS $API_SERVER_BONDS $STR_SERVER_BONDS $STM_SERVER_BONDS $TNT_SERVER_BONDS; do 
for SERVER_BOND in $EXT_SERVER_BONDS $API_SERVER_BONDS $STR_SERVER_BONDS $STM_SERVER_BONDS $TNT_SERVER_BONDS; do 
  SERVER=`echo $SERVER_BOND | awk -F':' '{print $1}'`
  IF=`echo $SERVER_BOND | awk -F':' '{print $2}'`
  BOND=`echo $SERVER_BOND | awk -F':' '{print $3}'`
  echo BONDIFYING $SERVER $IF $BOND
  ssh_control_sync_as_user root make_bond.sh /root/make_bond.sh $SERVER
  ssh_control_run_as_user root "nohup /root/make_bond.sh $IF $BOND &" $SERVER
  sleep 5
done

for SERVER in kgn neo bmn lmn mtn str mrl gnd; do
  ssh_control_sync_as_user root setup_bonds.sh /root/setup_bonds.sh $SERVER
  ssh_control_run_as_user root "/root/setup_bonds.sh" $SERVER
  sleep 5
done
