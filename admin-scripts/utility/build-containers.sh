#!/bin/bash

# FROM: https://twpower.github.io/180-build-kolla-images-from-source-en

SUDO_PASS_FILE=~/.password

LOCAL_DOCKER_REGISTRY=192.168.127.220:4001
NOW=`date +%Y%m%d_%H%M`
NOW_TARBALLS=/registry/kolla_tarballs/victoria_$NOW
TAG=feralcoder-$NOW
KOLLA_CODE_DIR=~/CODE/openstack/kolla

fail_exit () {
  echo; echo "FAILED: $1"
  exit 1
}

new_venv () {
  mkdir -p ~/CODE/venvs/kolla &&
  python3 -m venv ~/CODE/venvs/kolla
}

use_venv () {
  source ~/CODE/venvs/kolla/bin/activate
}


install_packages () {
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null   || return 1
  sudo yum -y install epel-release               || return 1
  sudo yum -y install python36-devel git python3 python3-pip gcc   || return 1
  pip3 install --upgrade pip                     || return 1
}

setup_kolla () {
  mkdir -p ~/CODE/openstack && cd ~/CODE/openstack       || return 1
  ( git clone https://github.com/openstack/kolla.git && cd kolla ) || ( cd kolla && git pull )       || return 1
  git checkout stable/victoria                           || return 1
  cd ..
  pip3 install kolla/                                    || return 1
  pip3 install tox                                       || return 1
}

generate_kolla_build_configs () {
  cd $KOLLA_CODE_DIR   || return 1
  tox -e genconfig     || return 1
}

fetch_kolla_container_source () {
  cd $KOLLA_CODE_DIR                                                          || return 1
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null                                || return 1
  sudo mkdir -p $NOW_TARBALLS && sudo chown cliff:cliff $NOW_TARBALLS         || return 1
  grep '^#location = .*tar.gz' etc/kolla/kolla-build.conf > $NOW_TARBALLS/locations || return 1
  sed -i 's|^#location = .tarballs_base|wget -P $NOW_TARBALLS https://tarballs.opendev.org|g' $NOW_TARBALLS/locations || return 1
  sed -i 's|^#location = |wget -P $NOW_TARBALLS |g' $NOW_TARBALLS/locations   || return 1
  sed -E -i 's/^(wget .*)/\1 || return 1/g' $NOW_TARBALLS/locations           || return 1
  . $NOW_TARBALLS/locations
}

build_kolla_containers () {
  cd $KOLLA_CODE_DIR   || return 1
  cat etc/kolla/kolla-build.conf | sed -E 's/#type = url/type = local/g' |  sed -E "s|^#location = .tarballs_base.*/([^/]*.tar.gz)|location = $NOW_TARBALLS/\1|g" | sed -E "s|^#location = .*/([^/]*.tar.gz)|location = $NOW_TARBALLS/\1|g" > etc/kolla/kolla-build-local.conf
  # kolla will use tag "8" with following base image...
  BASE_IMAGE="--base-image $LOCAL_DOCKER_REGISTRY/feralcoder/centos-feralcoder"
  kolla-build -t source -b centos $BASE_IMAGE --push --registry $LOCAL_DOCKER_REGISTRY -n feralcoder --tag $TAG   --config-file etc/kolla/kolla-build-local.conf --profile failed    || return 1
}

tag_as_latest () {
  for CONTAINER in `docker image list | grep $TAG | awk '{print $1}'`; do
    docker tag $CONTAINER:$TAG $CONTAINER:latest    || return 1
    docker push $CONTAINER:latest                   || return 1
  done
}


new_venv                        || faile_exit "new_venv"
use_venv                          || faile_exit "use_venv"
install_packages                || faile_exit "install_packages"
setup_kolla                     || faile_exit "setup_kolla"
generate_kolla_build_configs    || faile_exit "generate_kolla_build_configs"
fetch_kolla_container_source    || faile_exit "fetch_kolla_container_source"
build_kolla_containers            || faile_exit "build_kolla_containers"
tag_as_latest                   || faile_exit "tag_as_latest"