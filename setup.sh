#!/bin/bash


install_prereqs () {
  sudo dnf install python3-devel libffi-devel gcc openssl-devel python3-libselinux
  new_venv
  use_venv
  pip install -U pip
  pip install 'ansible<2.10'
}


new_venv () {
  python3 -m venv /path/to/venv
}

use_venv () {
  source /path/to/venv/bin/activate
}


install_kolla () {
  pip install kolla-ansible
  sudo mkdir -p /etc/kolla
  sudo chown $USER:$USER /etc/kolla
  cp -r /path/to/venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
  cp /path/to/venv/share/kolla-ansible/ansible/inventory/* .
}


install_prereqs
install_kolla
