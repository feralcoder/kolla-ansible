#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( dirname $KOLLA_SETUP_SOURCE )


get_sudo_password () {
  local PASSWORD

  read -s -p "Enter Sudo Password: " PASSWORD
  touch /tmp/password_$$
  chmod 600 /tmp/password_$$
  echo $PASSWORD > /tmp/password_$$
  echo /tmp/password_$$
}

new_venv () {
  mkdir -p ~/CODE/venvs/kolla-ansible
  python3 -m venv ~/CODE/venvs/kolla-ansible
}

use_venv () {
  source ~/CODE/venvs/kolla-ansible/bin/activate
}

add_stack_user () {
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo useradd stack
  echo st@ck | sudo passwd stack --stdin
  ( sudo grep "stack ALL" /etc/sudoers.d/stack ) || { echo "stack ALL=(root) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/stack; }
  sudo chmod 0440 /etc/sudoers.d/stack
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
  cp ~/CODE/venvs/kolla-ansible/share/kolla-ansible/ansible/inventory/* .
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
  [[ -f /etc/ansible/ansible.cfg ]] || cp ~/CODE/feralcoder/kolla-ansible/files/first-ansible.cfg /etc/ansible/
  [[ -f ~/ansible.cfg ]] || cp ~/CODE/feralcoder/kolla-ansible/files/first-ansible.cfg ~/
}

install_extra_packages () {
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
  sudo dnf -y install sshpass
  sudo dnf config-manager --set-disabled epel-modular epel
}

SUDO_PASS_FILE=`get_sudo_password`
install_prereqs
install_kolla_for_admin
#install_kolla_for_dev
config_ansible
add_stack_user
install_extra_packages

rm $SUDO_PASS_FILE
