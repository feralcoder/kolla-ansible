#!/bin/bash

. bond_config.sh


for BOND_DEF in $CTL_SERVER_BONDS $EXT_SERVER_BONDS $API_SERVER_BOND $SSTR_SERVER_BONDS $STM_SERVER_BONDS $TNT_SERVER_BONDS; do
  SERVER=`echo $BOND_DEF | awk -F':' '{print $1}'`
  IF=`echo $BOND_DEF | awk -F':' '{print $2}'`
  BOND=`echo $BOND_DEF | awk -F':' '{print $3}'`
  ssh_control_run_as_user root "ifup $IF" $SERVER
done


