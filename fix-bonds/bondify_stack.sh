#!/bin/bash

. bond_config.sh

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
