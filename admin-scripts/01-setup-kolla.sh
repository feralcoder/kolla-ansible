#!/bin/bash
KOLLA_SETUP_SOURCE="${BASH_SOURCE[0]}"
KOLLA_SETUP_DIR=$( realpath `dirname $KOLLA_SETUP_SOURCE` )

. $KOLLA_SETUP_DIR/common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"



decrypt_secure_files () {
  # Password file encrypted via: openssl enc -aes-256-cfb8 -md sha256 -in $KOLLA_SETUP_DIR/../files/kolla-passwords.yml -out $KOLLA_SETUP_DIR/../files/kolla-passwords.yml.encrypted
  openssl enc --pass file:/home/cliff/.password -d -aes-256-cfb8 -md sha256 -in $KOLLA_SETUP_DIR/../files/kolla-passwords.yml.encrypted -out $KOLLA_SETUP_DIR/../files/kolla-passwords.yml &&
  cp $KOLLA_SETUP_DIR/../files/kolla-passwords.yml /etc/kolla/passwords.yml
}

setup_local_passwordless_sudo () {
  test_sudo || return 1
  ( sudo grep "cliff ALL" /etc/sudoers.d/cliff >/dev/null 2>&1 ) || { echo "cliff ALL=(root) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/cliff; }
  sudo chmod 0440 /etc/sudoers.d/cliff
}



add_stack_user_everywhere () {
  echo; echo "ADDIING STACK USER EVERYWHERE"
  ssh_control_run_as_user_these_hosts root "adduser stack || id -u stack" "$ALL_HOSTS" 2>/dev/null                                || return 1
  [[ -f ~/.stack_password ]] && {
    PASSFILE=~/.stack_password
  } || {
    echo "Enter stack user password:"
    PASSFILE=`ssh_control_get_password ~/.stack_password false`                                                    || return 1
  }
  chmod 600 ~/.stack_password
  ssh_control_sync_as_user_these_hosts root ~/.stack_password /tmp/.stack_password "$ALL_HOSTS" 2>/dev/null                                                      || { echo "Failed to sync stack password."; return 1; }
  ssh_control_run_as_user_these_hosts  root "cat /tmp/.stack_password /tmp/.stack_password | passwd stack 2>&1" "$ALL_HOSTS" 2>/dev/null                         || { echo "Failed to set stack password."; return 1; }

  echo; echo "ADDING STACK USER TO LOCAL SUDOERS"
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  (( sudo grep "stack ALL.*NOPASSWD" /etc/sudoers.d/stack >/dev/null 2>&1 ) || { echo "stack ALL=(root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/stack >/dev/null; })    || { echo "Failed to add stack to local sudoers."; return 1; }
  sudo chmod 0440 /etc/sudoers.d/stack || return 1

  echo; echo "ADDING STACK USER TO SUDOERS EVERYWHERE"
  sudo cp /etc/sudoers.d/stack /tmp/stack && sudo chown cliff:cliff /tmp/stack
  ssh_control_sync_as_user_these_hosts root /tmp/stack /etc/sudoers.d/stack "$ALL_HOSTS" 2>/dev/null               || { echo "Failed to add stack to all sudoers."; return 1; }
  ssh_control_run_as_user_these_hosts root "chown root:root /etc/sudoers.d/stack 2>&1" "$ALL_HOSTS" 2>/dev/null    || { echo "Failed to fix sudoers ownership and perms."; return 1; }
  rm -f /tmp/stack
}



setup_stack_keys_and_sync () {
  echo; echo "SETTING UP LOCAL STACK .ssh DIRECTORY"
  STACK_SSHDIR=~stack/.ssh/

  test_sudo || return 1
  sudo su - stack -c "[[ -f $STACK_SSHDIR/id_rsa.pub ]] || ssh-keygen -f $STACK_SSHDIR/id_rsa -P ''"    || { echo "Could not find or setup stack's public key."; return 1; }

  echo; echo "PUT STACKS PUBKEY INTO STACKS authorized_keys FILE"
  ADMIN_KEY=`cat ~/.ssh/pubkeys/id_rsa.pub`           &&
  STACK_KEY=`sudo cat $STACK_SSHDIR/id_rsa.pub`       &&
  ADMIN_KEYPRINT=`echo $ADMIN_KEY | awk '{print $2}'` &&
  STACK_KEYPRINT=`echo $STACK_KEY | awk '{print $2}'` ||  return 1
  sudo su - stack -c "touch $STACK_SSHDIR/authorized_keys && chmod 600 $STACK_SSHDIR/authorized_keys"    ||  { echo "Could not fix mod or perms on stack authorized_keys"; return 1; }
  sudo su - stack -c "( grep "$ADMIN_KEYPRINT" $STACK_SSHDIR/authorized_keys >/dev/null ) || echo $STACK_KEY >> $STACK_SSHDIR/authorized_keys"    ||  { echo "Could not add admin key to stack's authorized_keys"; return 1; }
  sudo su - stack -c "( grep "$STACK_KEYPRINT" $STACK_SSHDIR/authorized_keys >/dev/null ) || echo $ADMIN_KEY >> $STACK_SSHDIR/authorized_keys"    ||  { echo "Could not add stack key to stack's authorized_keys"; return 1; }

  echo; echo "SYNC ~stack/.ssh/ TO STACK EVERYWHERE"
  sudo chown cliff:cliff -R ~stack/
  ssh_control_sync_as_user_these_hosts root $STACK_SSHDIR/ $STACK_SSHDIR/ "$ALL_HOSTS" 2>/dev/null    ||  { echo "Could not sync stack's ssh dir."; return 1; }
  ssh_control_run_as_user_these_hosts root "chown stack:stack -R ~stack/" "$ALL_HOSTS" 2>/dev/null    ||  { echo "could not fix mod or perms on stack's ssh dirs"; return 1; }
}





install_prereqs () {
  echo; echo "INSTALLING PREREQ'S"
  test_sudo || return 1
  sudo dnf -y install python3-devel libffi-devel gcc openssl-devel python3-libselinux &&
  new_venv kolla-ansible &&
  use_venv kolla-ansible &&
  pip install -U pip &&
  pip install 'ansible<2.10' || return 1
}

install_kolla_for_admin () {
  echo; echo "INSTALLING KOLLA FOR ADMINISTRATION"
  pip install 'kolla-ansible==12.0.0.0rc1'                                                               ||  return 1
  test_sudo || return 1
  sudo mkdir -p /etc/kolla
  sudo chown $USER:$USER /etc/kolla
  cp -r ~/CODE/venvs/kolla-ansible/share/kolla-ansible/etc_examples/kolla/* /etc/kolla    ||  return 1
  # We start with local docker registry, so hosts bootstrap with appropriate insecure-registries defined...
  cp $KOLLA_SETUP_DIR/../files/kolla-globals-localpull.yml /etc/kolla/globals.yml         ||  return 1
  cat $KOLLA_SETUP_DIR/../files/kolla-globals-remainder.yml >> /etc/kolla/globals.yml     ||  return 1

  # cp ~/CODE/venvs/kolla-ansible/share/kolla-ansible/ansible/inventory/* .
}

# Following is out of step with many subsequent changes
#install_kolla_for_dev () {
#  echo; echo "INSTALLING KOLLA FOR DEVELOPMENT"
#  git clone https://github.com/openstack/kolla
#  git clone https://github.com/openstack/kolla-ansible
#  pip install ./kolla
#  pip install ./kolla-ansible
#  test_sudo || return 1
#  sudo mkdir -p /etc/kolla
#  sudo chown $USER:$USER /etc/kolla
#  cp -r ~/CODE/feralcoder/kolla-ansible/etc/kolla/* /etc/kolla &&
#  cp ~/CODE/feralcoder/kolla-ansible/ansible/inventory/* .     &&
#  cp $KOLLA_SETUP_DIR/../files/kolla-globals.yml /etc/kolla/globals.yml                   || return 1
#}

disable_firewall () {
  echo; echo "DISABLE FIREWALLD"
  ssh_control_run_as_user_these_hosts root "systemctl disable firewalld" "$STACK_HOSTS"                    || return 1
  ssh_control_run_as_user_these_hosts root "systemctl stop firewalld" "$STACK_HOSTS"                       || return 1
}

config_ansible () {
  echo; echo "CONFIGURING ANSIBLE"
  test_sudo || return 1
  sudo mkdir -p /etc/ansible
  [[ -f /etc/ansible/ansible.cfg ]] || sudo cp ~/CODE/feralcoder/kolla-ansible/files/first-ansible.cfg /etc/ansible/ansible.cfg || return 1
  [[ -f ~/ansible.cfg ]] || cp ~/CODE/feralcoder/kolla-ansible/files/first-ansible.cfg ~/ansible.cfg                            || return 1
}

install_extra_packages () {
  echo; echo "INSTALLING EXTRA PACKAGES"
  test_sudo || return 1
  sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm  || return 1
  sudo dnf -y install sshpass   || return 1
  sudo dnf config-manager --set-disabled epel-modular epel   || return 1
}

other_sytem_hackery_for_setup () {
  echo; echo "OTHER SYSTEM HACKERY"
  ssh_control_run_as_user_these_hosts root "dnf -y erase buildah podman" "$STACK_HOSTS" 2>/dev/null || return 1
  ssh_control_sync_as_user_these_hosts root $KOLLA_SETUP_DIR/../files/90-networkmanager-go-fuck-yourself.conf /etc/NetworkManager/conf.d/ "$STACK_HOSTS" || return 1
  ssh_control_run_as_user_these_hosts root "systemctl reload NetworkManager" "$STACK_HOSTS" || return 1

  # Disable Reverse Path Filtering: Switches send routed traffic directly to any network, but default route back is via 192.168.127.X.
  ssh_control_run_as_user_these_hosts root "echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter" "$STACK_HOSTS" || return 1
  ssh_control_run_as_user_these_hosts root "( grep 'net.ipv4.conf.all.rp_filter' /etc/sysctl.conf ) && sed -i 's/net.ipv4.conf.all.rp_filter.*/net.ipv4.conf.all.rp_filter=0/g' /etc/sysctl.conf || echo net.ipv4.conf.all.rp_filter=0 >> /etc/sysctl.conf" "$STACK_HOSTS" || return 1
}



host_control_updates () {
  echo; echo "UPDATING REPOS EVERYWHERE"
  git_control_pull_push_these_hosts "$ALL_HOSTS" 2>/dev/null  ||  return 1

  echo; echo "UPDATING cliff ADMIN ENV FROM workstation/update.sh EVERYWHERE (to update /etc/hosts mainly...)"
  ssh_control_sync_as_user_these_hosts cliff ~/.password ~/.password "$ALL_HOSTS" || return 1
  ssh_control_run_as_user_these_hosts cliff "./CODE/feralcoder/workstation/update.sh" "$ALL_HOSTS" || return 1                    # Set up /etc/hosts

  echo; echo "REFETCHING ILO KEYS EVERYWHERE"
#  # Serialize to not hose ILO's
#  for HOST in $ALL_HOSTS; do
#     echo; echo "Getting ILO hostkeys on $HOST"
#     ssh_control_run_as_user cliff "ilo_control_refetch_ilo_hostkey_these_hosts \"$ALL_HOSTS\"" $HOST 2>/dev/null
#  done   ||  { echo "Could not refetch ILO keys everywhere"; return 1; }

  echo; echo "REFETCHING HOST KEYS EVERYWHERE"
  ssh_control_refetch_hostkey_these_hosts "$ALL_HOSTS"     ||  { echo "Could not refetch host keys."; return 1; }

  echo; echo "RENAMING STACK HOSTS TO THEIR API-NET-RESOLVING NAMES"
  ssh_control_run_as_user_these_hosts root "( hostname | grep -vE '^[^\.]+-api' ) && \
                                   { hostname \`hostname | sed -E 's/^([^\.]+)/\1-api/g'\` > /dev/null; \
                                   hostname ; } || echo hostname is already apid" "$STACK_HOSTS"    ||  { echo "Could not set hostnames to hostnames-api"; return 1; }
  ssh_control_run_as_user_these_hosts root "hostnamectl set-hostname \`hostname\`" "$STACK_HOSTS"   ||  { echo "Could not cement hostnames"; return 1; }
  for i in $ALL_HOSTS; do ssh root@$i hostname; done
}

setup_octavia_certs () {
# THIS HAS BEEN TOTAL FAILURE
  # Certs generated by $KOLLA_SETUP_DIR/utility/octavia_certs/make-certs.sh
  mkdir -p /etc/kolla/config/octavia
  cp $KOLLA_SETUP_DIR/utility/octavia_certs/client_ca/private/client.cert-and-key.pem /etc/kolla/config/octavia/            || return 1
  cp $KOLLA_SETUP_DIR/utility/octavia_certs/client_ca/certs/client.cert.pem /etc/kolla/config/octavia/client_ca.cert.pem    || return 1
  cp $KOLLA_SETUP_DIR/utility/octavia_certs/server_ca/certs/ca.cert.pem /etc/kolla/config/octavia/server_ca.cert.pem        || return 1
  cp $KOLLA_SETUP_DIR/utility/octavia_certs/server_ca/private/ca.key.pem /etc/kolla/config/octavia/server_ca.key.pem        || return 1
}


SUDO_PASS_FILE=`admin_control_get_sudo_password ~/.password`
setup_local_passwordless_sudo  || fail_exit "setup_local_passwordless_sudo"
add_stack_user_everywhere      || fail_exit "add_stack_user_everywhere"
setup_stack_keys_and_sync      || fail_exit "setup_stack_keys_and_sync"

install_prereqs                || fail_exit "install_prereqs"
install_kolla_for_admin        || fail_exit "install_kolla_for_admin"
decrypt_secure_files           || fail_exit "decrypt_secure_files"
#install_kolla_for_dev         || fail_exit "install_kolla_for_dev"
config_ansible                 || fail_exit "config_ansible"
install_extra_packages         || fail_exit "install_extra_packages"
other_sytem_hackery_for_setup  || fail_exit "other_sytem_hackery_for_setup"
disable_firewall               || fail_exit "disable_firewall"

host_control_updates           || fail_exit "host_control_updates"
setup_octavia_certs            || fail_exit "setup_octavia_certs"



[[ $SUDO_PASS_FILE == ~/.password ]] || rm $SUDO_PASS_FILE
