#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( dirname $KOLLA_SETUP_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh



get_sudo_password () {
  local PASSWORD

  read -s -p "Enter Sudo Password: " PASSWORD
  touch /tmp/password_$$
  chmod 600 /tmp/password_$$
  echo $PASSWORD > /tmp/password_$$
  echo /tmp/password_$$
}

setup_local_passwordless_sudo () {
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  ( sudo grep "cliff ALL" /etc/sudoers.d/cliff ) || { echo "cliff ALL=(root) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/cliff; }
  sudo chmod 0440 /etc/sudoers.d/cliff
}

new_venv () {
  mkdir -p ~/CODE/venvs/kolla-ansible
  python3 -m venv ~/CODE/venvs/kolla-ansible
}

use_venv () {
  source ~/CODE/venvs/kolla-ansible/bin/activate
}




add_stack_user_everywhere () {
  # Add stack user everywhere
  ssh_control_run_as_user_these_hosts root "adduser stack" "$ALL_HOSTS"
  echo "Enter stack user password:"
  PASSFILE=`ssh_control_get_password`
  mv $PASSFILE ~/.stack_password
  chmod 600 ~/.stack_password
  ssh_control_sync_as_user_these_hosts root ~/.stack_password /tmp/.stack_password "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts  root "cat /tmp/.stack_password /tmp/.stack_password | passwd stack" "$ALL_HOSTS"

  # Add stack to sudoers on localhost
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  ( sudo grep "stack ALL" /etc/sudoers.d/stack ) || { echo "stack ALL=(root) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/stack; }
  sudo chmod 0440 /etc/sudoers.d/stack
  # Add stack to sudoers everywhere
  sudo cp /etc/sudoers.d/stack /tmp/stack && sudo chown cliff:cliff /tmp/stack
  ssh_control_sync_as_user_these_hosts root /tmp/stack /etc/sudoers.d/stack "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts root "chown root:root /etc/sudoers.d/stack" "$ALL_HOSTS"
  rm -f /tmp/stack
}

setup_stack_keys_and_sync () {
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
  # Put own stack's own pubkey into authorized_keys if needed
  ADMIN_KEY=`cat $STACK_SSHDIR/pubkeys/id_rsa.pub`
  KEYPRINT=`echo $ADMIN_KEY | awk '{print $2}'`
  sudo su - stack -c 'cat $STACK_SSHDIR/id_rsa.pub >> $STACK_SSHDIR/authorized_keys && chmod 600 $STACK_SSHDIR/authorized_keys'
  sudo su - stack -c "( grep "$KEYPRINT" $STACK_SSHDIR/authorized_keys ) || cat $STACK_SSHDIR/id_rsa.pub >> $STACK_SSHDIR/authorized_keys"
  # Sync ~stack/.ssh/ to all hosts
  sudo chown cliff:cliff -R ~stack/
  ssh_control_sync_as_user_these_hosts root $STACK_SSHDIR/ $STACK_SSHDIR/ "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts root "chown stack:stack -R ~stack/" "$ALL_HOSTS"
}










install_prereqs () {
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo dnf install python3-devel libffi-devel gcc openssl-devel python3-libselinux -y
  new_venv
  use_venv
  pip install -U pip
  pip install 'ansible<2.10'
}

install_kolla_for_admin () {
  pip install kolla-ansible
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo mkdir -p /etc/kolla
  sudo chown $USER:$USER /etc/kolla
  cp -r ~/CODE/venvs/kolla-ansible/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
  # cp ~/CODE/venvs/kolla-ansible/share/kolla-ansible/ansible/inventory/* .
}

install_kolla_for_dev () {
  git clone https://github.com/openstack/kolla
  git clone https://github.com/openstack/kolla-ansible
  pip install ./kolla
  pip install ./kolla-ansible
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo mkdir -p /etc/kolla
  sudo chown $USER:$USER /etc/kolla
  cp -r ~/CODE/feralcoder/kolla-ansible/etc/kolla/* /etc/kolla
  cp ~/CODE/feralcoder/kolla-ansible/ansible/inventory/* .
}

config_ansible () {
  [[ -f /etc/ansible/ansible.cfg ]] || cp ~/CODE/feralcoder/kolla-ansible/files/first-ansible.cfg /etc/ansible/ansible.cfg
  [[ -f ~/ansible.cfg ]] || cp ~/CODE/feralcoder/kolla-ansible/files/first-ansible.cfg ~/ansible.cfg
}

install_extra_packages () {
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
  sudo dnf -y install sshpass
  sudo dnf config-manager --set-disabled epel-modular epel
}

other_sytem_hackery_for_setup () {
  ssh_control_run_as_user_these_hosts root "dnf -y erase buildah podman" "$ALL_HOSTS"
}



SUDO_PASS_FILE=`get_sudo_password`
setup_local_passwordless_sudo
add_stack_user_everywhere
setup_stack_keys_and_sync

install_prereqs
install_kolla_for_admin
#install_kolla_for_dev
config_ansible
install_extra_packages
other_sytem_hackery_for_setup

rm $SUDO_PASS_FILE
