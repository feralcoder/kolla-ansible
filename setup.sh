#!/bin/bash

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
  sudo mkdir -p /etc/kolla
  sudo chown $USER:$USER /etc/kolla
  cp -r ~/CODE/feralcoder/kolla-ansible/etc/kolla/* /etc/kolla
  cp ~/CODE/feralcoder/kolla-ansible/ansible/inventory/* .
}

config_ansible () {
  [[ -f /etc/ansible/ansible.cfg ]] || cp ~/CODE/feralcoder/kolla-ansible/files/first-ansible.cfg /etc/ansible/
  [[ -f ~/ansible.cfg ]] || cp ~/CODE/feralcoder/kolla-ansible/files/first-ansible.cfg ~/
}

SUDO_PASS_FILE=`get_sudo_password`
install_prereqs
install_kolla_for_admin
#install_kolla_for_dev
config_ansible


rm $SUDO_PASS_FILE
