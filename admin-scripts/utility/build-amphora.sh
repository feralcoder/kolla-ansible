#!/bin/bash

SUDO_PASS_FILE=~/.password
REGISTRY_HOST=dmb
CACHE_DIR=~/amphora_cache/


DIB_REPO_PATH=~/CODE/openstack/diskimage-builder/diskimage_builder
DIB_REPOLOCATION_amphora_agent=~/CODE/openstack/octavia
DIB_REPOREF_amphora_agent="stable/victoria"
OCTAVIA_REPO_PATH=~/CODE/openstack/octavia

set_passwordless_sudo () {
  # Need USER to be passwordless sudoer, because disk-image-create calls sudo, with millions of minutes between
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/temp_$USER
}
remove_passwordless_sudo () {
  # Remove temporary passwordless sudo
  sudo rm /etc/sudoers.d/temp_$USER
}

setup_env () {
  sudo yum install -y python3-pip python3-virtualenv
  python3 -m pip install --upgrade pip
  python3 -m venv ~/CODE/venvs/amphora_builder
  . ~/CODE/venvs/amphora_builder/bin/activate
  
  sudo yum install -y libguestfs-tools
  sudo dnf install -y qemu-img git e2fsprogs policycoreutils-python-utils
  
  mkdir -p ~/CODE/openstack && cd ~/CODE/openstack
  [[ -d ~/CODE/openstack/octavia ]] || git clone https://github.com/openstack/octavia
  [[ -d ~/CODE/openstack/diskimage-builder ]] || git clone https://github.com/openstack/diskimage-builder
  cd ~/CODE/openstack/octavia/diskimage-create
  pip3 install -r requirements.txt
}


build_amphora () {
  $OCTAVIA_REPO_PATH/diskimage-create/diskimage-create.sh -c $CACHE_DIR/.cache -o $CACHE_DIR/amphora-x64-haproxy.qcow2 -a amd64 -t qcow2 -i centos-minimal -g "stable/victoria" -r p7mp7n -w $OCTAVIA_REPO_PATH/diskimage-create
  ssh_control_sync_as_user root $CACHE_DIR/amphora-x64-haproxy.qcow2 /registry/images/amphora-x64-centos-haproxy.qcow2 $REGISTRY_HOST
  #ssh_control_run_as_user cliff ". ~/CODE/venvs/kolla-ansible/bin/activate && . /etc/kolla/admin-openrc.sh && openstack image create --container-format bare --disk-format qcow2 --public --file /registry/images/amphora-x64-centos-haproxy.qcow2 --min-disk 2 --min-ram 1024 --tag amphora amphora --project service" $REGISTRY_HOST
}

convert_raw_to_qcow2 () {
  local RAW_IMG=$1 QCOW2_IMG=$2
  qemu-img convert -f raw -O qcow2 $RAW_IMG $QCOW2_IMG
}

convert_qcow2_to_raw () {
  local QCOW2_IMG=$1 RAW_IMG=$2
  qemu-img convert -f qcow2 -O raw $QCOW2_IMG $RAW_IMG
}

mount_raw_image () {
  local RAW_IMG=$1 MOUNTPOINT=$2
  sudo losetup -f -P $RAW_IMG
  local LO_DEV=`sudo losetup -l | grep $RAW_IMG | awk '{print $1'}`
  # Do only for first loop device matched
  for DEV in $LO_DEV; do
    sudo mount ${DEV}p1 $MOUNTPOINT
    return 0
  done
}

umount_raw_image () {
  local RAW_IMG=$1 MOUNTPOINT=$2
  sudo umount $MOUNTPOINT
  local LO_DEV=`sudo losetup -l | grep $RAW_IMG | awk '{print $1'}`
  for DEV in $LO_DEV; do
    sudo umount ${DEV}p1
    sudo losetup -d $DEV
  done
}

set_passwordless_sudo
setup_env
#build_amphora
remove_passwordless_sudo



# TO OPERATE ON QCOW IMAGE

