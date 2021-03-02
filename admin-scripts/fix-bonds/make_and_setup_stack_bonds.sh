#!/bin/bash
BONDSCRIPT_SOURCE="${BASH_SOURCE[0]}"
BONDSCRIPT_DIR=$( dirname $BONDSCRIPT_SOURCE )

. $BONDSCRIPT_DIR/bond_config.sh

for SERVER_BOND in $CTL_SERVER_BONDS $EXT_SERVER_BONDS $API_SERVER_BONDS $STR_SERVER_BONDS $STM_SERVER_BONDS $TNT_SERVER_BONDS; do 
  SERVER=`echo $SERVER_BOND | awk -F':' '{print $1}'`
  IF=`echo $SERVER_BOND | awk -F':' '{print $2}'`
  BOND=`echo $SERVER_BOND | awk -F':' '{print $3}'`
  echo BONDIFYING $SERVER $IF $BOND
  ssh_control_sync_as_user root $BONDSCRIPT_SOURCE/scripts/make_bond.sh /root/make_bond.sh $SERVER
  ssh_control_run_as_user root "nohup /root/make_bond.sh $IF $BOND &" $SERVER
done

ssh_control_sync_as_user root $BONDSCRIPT_SOURCE/scripts/setup_host_bonds.sh /root/setup_host_bonds.sh $SERVER
ssh_control_run_as_user root "nohup /root/setup_host_bonds.sh &" $SERVER
