#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( dirname $KOLLA_SETUP_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

add_stack_user () {
  # Add stack user everywhere
  ssh_control_run_as_user_these_hosts root "adduser stack" "$ALL_HOSTS"
  echo "Enter stack user password:"
  PASSFILE=`ssh_control_get_password`
  mv $PASSFILE ~/.stack_password
  chmod 600 ~/.stack_password
  ssh_control_sync_as_user_these_hosts root ~/.stack_password /tmp/.stack_password "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts  root "cat /tmp/.stack_password /tmp/.stack_password | passwd stack" "$ALL_HOSTS"

  # Add stack to sudoers everywhere
  sudo cp /etc/sudoers.d/stack /tmp/stack && sudo chown cliff:cliff /tmp/stack
  ssh_control_sync_as_user_these_hosts root /tmp/stack /etc/sudoers.d/stack "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts root "chown root:root /etc/sudoers.d/stack" "$ALL_HOSTS"
  rm -f /tmp/stack
}

setup_keys () {
  [[ -f ~/.password ]] || { 
    echo "Enter sudo password:" 
    PASSFILE=`ssh_control_get_password`
    mv $PASSFILE ~/.password
    chmod 600 ~/.password
  }
  
  # Set up ~stack/.ssh directory if needed
  STACK_SSHDIR=~stack/.ssh/
  cat ~/.password | sudo -S ls >/dev/null
  sudo su - stack -c '[[ -f $STACK_SSHDIR/id_rsa.pub ]] || ssh-keygen -f $STACK_SSHDIR/id_rsa -P ""'
  # Put own pubkey into authorized_keys if needed
  ADMIN_KEY=`cat $STACK_SSHDIR/pubkeys/id_rsa.pub`
  KEYPRINT=`echo $ADMIN_KEY | awk '{print $2}'`
  sudo su - stack -c 'cat $STACK_SSHDIR/id_rsa.pub >> $STACK_SSHDIR/authorized_keys && chmod 600 $STACK_SSHDIR/authorized_keys'
  sudo su - stack -c "( grep "$KEYPRINT" $STACK_SSHDIR/authorized_keys ) || cat $STACK_SSHDIR/id_rsa.pub >> $STACK_SSHDIR/authorized_keys"
  # Sync ~stack/.ssh/ to all hosts
  sudo chown cliff:cliff -R ~stack/
  ssh_control_sync_as_user_these_hosts root $STACK_SSHDIR/ $STACK_SSHDIR/ "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts root "chown stack:stack -R ~stack/" "$ALL_HOSTS"
}

add_stack_user
setup_keys
