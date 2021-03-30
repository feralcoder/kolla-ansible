#!/bin/bash

[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

. bond_config.sh


for BOND_DEF in $CTL_SERVER_BONDS $EXT_SERVER_BONDS $API_SERVER_BONDS $STR_SERVER_BONDS $STM_SERVER_BONDS $TNT_SERVER_BONDS; do
  SERVER=`echo $BOND_DEF | awk -F':' '{print $1}'`
  IF=`echo $BOND_DEF | awk -F':' '{print $2}'`
  BOND=`echo $BOND_DEF | awk -F':' '{print $3}'`
  ssh_control_run_as_user root "ifup $IF ; sleep 3" $SERVER
done


