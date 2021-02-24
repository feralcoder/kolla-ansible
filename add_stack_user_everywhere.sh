#!/bin/bash

. ~/CODE/feralcoder/host_control/control_scripts.sh

add_stack_user () {
  ssh_control_run_as_user_these_hosts root "adduser stack" "$ALL_HOSTS"
  PASSFILE=`ssh_control_get_password`
  mv $PASSFILE ~/.stack_password
  chmod 600 ~/.stack_password
  ssh_control_sync_as_user_these_hosts root ~/.stack_password /tmp/.stack_password "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts  root "cat /tmp/.stack_password /tmp/.stack_password | passwd stack" "$ALL_HOSTS"
}

setup_keys () {
  [[ -f ~/.password ]] || { 
    echo "Enter sudo password:" 
    PASSFILE=`ssh_control_get_password`
    mv $PASSFILE ~/.password
    chmod 600 ~/.password
  }
  
  cat ~/.password | sudo -S ls >/dev/null
  sudo su - stack -c 'ssh-keygen -f /home/stack/.ssh/id_rsa -P ""'
  sudo su - stack -c 'cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
  ADMIN_KEY=`cat ~/.ssh/pubkeys/id_rsa.pub`
  sudo su - stack -c "echo $ADMIN_KEY >> ~/.ssh/authorized_keys"

  sudo chown cliff:cliff -R ~stack/
  ssh_control_sync_as_user_these_hosts root ~stack/.ssh/ ~stack/.ssh/ "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts root "chown stack:stack -R ~stack/" "$ALL_HOSTS"
}

add_stack_user
setup_keys
