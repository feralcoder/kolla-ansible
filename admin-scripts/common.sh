#!/bin/bash

bail_if_sourced () {
  if [ ! "${BASH_SOURCE[0]}" -ef "$0" ]; then
    echo "Do not source this script (exits will bail you...)."
    echo "Run it instead"
    exit 1
  fi
}

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


