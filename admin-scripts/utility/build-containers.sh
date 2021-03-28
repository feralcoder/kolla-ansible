#!/bin/bash

# FROM: https://twpower.github.io/180-build-kolla-images-from-source-en

SUDO_PASS_FILE=~/.password

LOCAL_DOCKER_REGISTRY=192.168.127.220:4001
NOW=`date +%Y%m%d_%H%M`
NOW_TARBALLS=/registry/kolla_tarballs/victoria_$NOW
TAG=feralcoder-$NOW
KOLLA_CODE_DIR=~/CODE/openstack/kolla

new_venv () {
  mkdir -p ~/CODE/venvs/kolla &&
  python3 -m venv ~/CODE/venvs/kolla
}

use_venv () {
  source ~/CODE/venvs/kolla/bin/activate
}


install_packages () {
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo yum -y install epel-release
  sudo yum -y install python36-devel git python3 python3-pip gcc
  pip3 install --upgrade pip
}

setup_kolla () {
  mkdir -p ~/CODE/openstack && cd ~/CODE/openstack
  ( git clone https://github.com/openstack/kolla.git && cd kolla ) || ( cd kolla && git pull )
  git checkout stable/victoria
  cd ..
  pip3 install kolla/
  pip3 install tox
}

generate_kolla_build_configs () {
  cd $KOLLA_CODE_DIR
  tox -e genconfig
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo mkdir -p $NOW_TARBALLS && sudo chown cliff:cliff $NOW_TARBALLS
{

fetch_kolla_source () {
  grep '^#location = .*tar.gz' etc/kolla/kolla-build.conf > $NOW_TARBALLS/locations
  sed -i 's|^#location = \$tarballs_base|wget https://tarballs.opendev.org|g' $NOW_TARBALLS/locations
  . $NOW_TARBALLS/locations
}

build_kolla_containers () {
  cat etc/kolla/kolla-build.conf | sed -E 's/#type = url/type = local/g' |  sed -E "s|^#location = $tarballs_base.*/([^/]*.tar.gz)|location = $NOW_TARBALLS/\1|g" > etc/kolla/kolla-build-local.conf
  # kolla will use tag "8" with following base image...
  BASE_IMAGE="--base-image $LOCAL_DOCKER_REGISTRY/feralcoder/centos-feralcoder"
  kolla-build -t source -b centos $BASE_IMAGE --push --registry $LOCAL_DOCKER_REGISTRY -n feralcoder --tag $TAG   --config-file etc/kolla/kolla-build-local.conf
}



new_venv
use_venv
install_packages

setup_kolla
generate_kolla_build_configs
fetch_kolla_source
build_kolla_containers
