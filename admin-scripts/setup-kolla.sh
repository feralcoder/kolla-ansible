#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )

. ~/CODE/feralcoder/host_control/control_scripts.sh



get_sudo_password () {
  local PASSWORD

  # if ~/.password exists and works, use it
  [[ -f ~/.password ]] && {
    cat ~/.password | sudo -k -S ls >/dev/null 2>&1
    if [[ $? == 0 ]] ; then
      echo ~/.password
      return
    fi
  }

  # either ~.password doesn't exiist, or it doesn't work
  read -s -p "Enter Sudo Password: " PASSWORD
  touch /tmp/password_$$
  chmod 600 /tmp/password_$$
  echo $PASSWORD > /tmp/password_$$
  echo /tmp/password_$$
}

decrypt_secure_files () {
  # Password file encrypted via: openssl enc -aes-256-cfb8 -md sha256 -in $KOLLA_SETUP_DIR/../files/passwords.yml -out $KOLLA_SETUP_DIR/../files/passwords.yml.encrypted
  openssl enc --pass file:/home/cliff/.password -d -aes-256-cfb8 -md sha256 -in $KOLLA_SETUP_DIR/../files/passwords.yml.encrypted -out $KOLLA_SETUP_DIR/../files/passwords.yml
  cp $KOLLA_SETUP_DIR/../files/passwords.yml /etc/kolla/
}

setup_local_passwordless_sudo () {
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  ( sudo grep "cliff ALL" /etc/sudoers.d/cliff >/dev/null 2>&1 ) || { echo "cliff ALL=(root) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/cliff; }
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
  echo; echo "ADDIING STACK USER EVERYWHERE"
  ssh_control_run_as_user_these_hosts root "adduser stack" "$ALL_HOSTS" 2>/dev/null
  [[ -f ~/.stack_password ]] && {
    PASSFILE=~/.stack_password
  } || {
    echo "Enter stack user password:"
    PASSFILE=`ssh_control_get_password ~/.stack_password false`
  }
  chmod 600 ~/.stack_password
  ssh_control_sync_as_user_these_hosts root ~/.stack_password /tmp/.stack_password "$ALL_HOSTS" 2>/dev/null
  ssh_control_run_as_user_these_hosts  root "cat /tmp/.stack_password /tmp/.stack_password | passwd stack 2>&1" "$ALL_HOSTS" 2>/dev/null

  echo; echo "ADDING STACK USER TO LOCAL SUDOERS"
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  ( sudo grep "stack ALL" /etc/sudoers.d/stack >/dev/null 2>&1 ) || { echo "stack ALL=(root) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/stack >/dev/null; }
  sudo chmod 0440 /etc/sudoers.d/stack

  echo; echo "ADDING STACK USER TO SUDOERS EVERYWHERE"
  sudo cp /etc/sudoers.d/stack /tmp/stack && sudo chown cliff:cliff /tmp/stack
  ssh_control_sync_as_user_these_hosts root /tmp/stack /etc/sudoers.d/stack "$ALL_HOSTS" 2>/dev/null
  ssh_control_run_as_user_these_hosts root "chown root:root /etc/sudoers.d/stack 2>&1" "$ALL_HOSTS" 2>/dev/null
  rm -f /tmp/stack
}

setup_stack_keys_and_sync () {
  [[ -f ~/.password ]] || {
    echo "Enter sudo password:"
    PASSFILE=`ssh_control_get_password ~/.password`
  }

  echo; echo "SETTING UP LOCAL STACK .ssh DIRECTORY"
  STACK_SSHDIR=~stack/.ssh/
  cat ~/.password | sudo -S ls >/dev/null
  sudo su - stack -c "[[ -f $STACK_SSHDIR/id_rsa.pub ]] || ssh-keygen -f $STACK_SSHDIR/id_rsa -P ''"

  echo; echo "PUT STACKS PUBKEY INTO STACKS authorized_keys FILE"
  ADMIN_KEY=`cat ~/.ssh/pubkeys/id_rsa.pub`
  STACK_KEY=`sudo cat $STACK_SSHDIR/id_rsa.pub`
  ADMIN_KEYPRINT=`echo $ADMIN_KEY | awk '{print $2}'`
  STACK_KEYPRINT=`echo $STACK_KEY | awk '{print $2}'`
  sudo su - stack -c "touch $STACK_SSHDIR/authorized_keys && chmod 600 $STACK_SSHDIR/authorized_keys"
  sudo su - stack -c "( grep "$ADMIN_KEYPRINT" $STACK_SSHDIR/authorized_keys >/dev/null ) || echo $STACK_KEY >> $STACK_SSHDIR/authorized_keys"
  sudo su - stack -c "( grep "$STACK_KEYPRINT" $STACK_SSHDIR/authorized_keys >/dev/null ) || echo $ADMIN_KEY >> $STACK_SSHDIR/authorized_keys"

  echo; echo "SYNC ~stack/.ssh/ TO STACK EVERYWHERE"
  sudo chown cliff:cliff -R ~stack/
  ssh_control_sync_as_user_these_hosts root $STACK_SSHDIR/ $STACK_SSHDIR/ "$ALL_HOSTS" 2>/dev/null
  ssh_control_run_as_user_these_hosts root "chown stack:stack -R ~stack/" "$ALL_HOSTS" 2>/dev/null
}





install_prereqs () {
  echo; echo "INSTALLING PREREQ'S"
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo dnf -y install python3-devel libffi-devel gcc openssl-devel python3-libselinux
  new_venv
  use_venv
  pip install -U pip
  pip install 'ansible<2.10'
}

install_kolla_for_admin () {
  echo; echo "INSTALLING KOLLA FOR ADMINISTRATION"
  pip install kolla-ansible
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo mkdir -p /etc/kolla
  sudo chown $USER:$USER /etc/kolla
  cp -r ~/CODE/venvs/kolla-ansible/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
  cp $KOLLA_SETUP_DIR/../files/globals.yml /etc/kolla/

  # cp ~/CODE/venvs/kolla-ansible/share/kolla-ansible/ansible/inventory/* .
}

install_kolla_for_dev () {
  echo; echo "INSTALLING KOLLA FOR DEVELOPMENT"
  git clone https://github.com/openstack/kolla
  git clone https://github.com/openstack/kolla-ansible
  pip install ./kolla
  pip install ./kolla-ansible
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo mkdir -p /etc/kolla
  sudo chown $USER:$USER /etc/kolla
  cp -r ~/CODE/feralcoder/kolla-ansible/etc/kolla/* /etc/kolla
  cp ~/CODE/feralcoder/kolla-ansible/ansible/inventory/* .
  cp $KOLLA_SETUP_DIR/../files/globals.yml /etc/kolla/
}

config_ansible () {
  echo; echo "CONFIGURING ANSIBLE"
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo mkdir -p /etc/ansible
  [[ -f /etc/ansible/ansible.cfg ]] || sudo cp ~/CODE/feralcoder/kolla-ansible/files/first-ansible.cfg /etc/ansible/ansible.cfg
  [[ -f ~/ansible.cfg ]] || cp ~/CODE/feralcoder/kolla-ansible/files/first-ansible.cfg ~/ansible.cfg
}

install_extra_packages () {
  echo; echo "INSTALLING EXTRA PACKAGES"
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
  sudo dnf -y install sshpass
  sudo dnf config-manager --set-disabled epel-modular epel
}

other_sytem_hackery_for_setup () {
  echo; echo "OTHER SYSTEM HACKERY"
  ssh_control_run_as_user_these_hosts root "dnf -y erase buildah podman" "$STACK_HOSTS" 2>/dev/null
  ssh_control_sync_as_user_these_hosts root $KOLLA_SETUP_DIR/../files/90-networkmanager-go-fuck-yourself.conf /etc/NetworkManager/conf.d/ "$STACK_HOSTS"
  ssh_control_run_as_user_these_hosts root "systemctl reload NetworkManager" "$STACK_HOSTS"
}



host_control_updates () {
  echo; echo "UPDATING REPOS EVERYWHERE"
  git_control_pull_push_these_hosts "$ALL_HOSTS" 2>/dev/null

  echo; echo "UPDATING cliff ADMIN ENV FROM workstation/update.sh EVERYWHERE (to update /etc/hosts mainly...)"
  ssh_control_sync_as_user_these_hosts cliff ~/.password ~/.password "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts cliff "./CODE/feralcoder/workstation/update.sh" "$ALL_HOSTS"                    # Set up /etc/hosts

  echo; echo "REFETCHING ILO KEYS EVERYWHERE"
#  # Serialize to not hose ILO's
#  for HOST in $ALL_HOSTS; do
#     echo; echo "Getting ILO hostkeys on $HOST"
#     ssh_control_run_as_user cliff "ilo_control_refetch_ilo_hostkey_these_hosts \"$ALL_HOSTS\"" $HOST 2>/dev/null
#  done

  echo; echo "REFETCHING HOST KEYS EVERYWHERE"
  ssh_control_refetch_hostkey_these_hosts "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts cliff "ssh_control_refetch_hostkey_these_hosts \"$ALL_HOSTS\"" "$ALL_HOSTS" 2>/dev/null

  echo; echo "RENAMING STACK HOSTS TO THEIR API-NET-RESOLVING NAMES"
  ssh_control_run_as_user_these_hosts root "( hostname | grep -vE '^[^\.]+-api' ) && \
                                   { hostname \`hostname | sed -E 's/^([^\.]+)/\1-api/g'\` > /dev/null; \
                                   hostname ; } || echo hostname is already apid" "$STACK_HOSTS"
  ssh_control_run_as_user_these_hosts root "hostnamectl set-hostname \`hostname\`" "$STACK_HOSTS"
  for i in $ALL_HOSTS; do ssh root@$i hostname; done
}


SUDO_PASS_FILE=`admin_control_get_sudo_password`
setup_local_passwordless_sudo
add_stack_user_everywhere
setup_stack_keys_and_sync

install_prereqs
install_kolla_for_admin
decrypt_secure_files
#install_kolla_for_dev
config_ansible
install_extra_packages
other_sytem_hackery_for_setup

host_control_updates


[[ $SUDO_PASS_FILE == ~/.password ]] || rm $SUDO_PASS_FILE
