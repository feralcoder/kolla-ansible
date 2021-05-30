#!/bin/bash
UTILITY_SOURCE="${BASH_SOURCE[0]}"
UTILITY_DIR=$( realpath `dirname $UTILITY_SOURCE` )

. $UTILITY_DIR/../common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"

# FROM: https://twpower.github.io/180-build-kolla-images-from-source-en
SUDO_PASS_FILE=~/.password

NOW=$1
INSTALL_TYPE=$2
OS_RELEASE=$3
SKIP_DL=$4
CONTAINER_REGEX=$5


[[ $NOW != "" ]]  ||  NOW=`date +%Y%m%d_%H%M`
[[ $INSTALL_TYPE != "" ]]  ||  { "echo INSTALL_TYPE not provided!"; exit 1; }
[[ $OS_RELEASE != "" ]]  ||  OS_RELEASE=wallaby
TAG=feralcoder-$OS_RELEASE-$NOW
NOW_TARBALLS=/registry/kolla_tarballs/$OS_RELEASE-$NOW

LOCAL_DOCKER_REGISTRY=192.168.127.220:4001
KOLLA_CODE_DIR=~/CODE/openstack/kolla



install_packages () {
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null   || return 1
  sudo yum -y install epel-release               || return 1
  sudo yum -y install python36-devel git python3 python3-pip gcc   || return 1
  pip3 install --upgrade pip                     || return 1
}

setup_kolla () {
  mkdir -p ~/CODE/openstack && cd ~/CODE/openstack       || return 1
#  git clone https://github.com/openstack/kolla.git       || { cd kolla && git pull && cd ..; }       || return 1
#  cd kolla && git checkout stable/$OS_RELEASE               || return 1
  git clone https://feralcoder:`cat ~/.git_password`@github.com/feralcoder/kolla.git    || { cd kolla && git pull && cd ..; } || return 1
  cd kolla && git checkout wallaby-feralcoder                || return 1
  cd ..
  pip3 install ./kolla                                    || return 1
  pip3 install tox                                       || return 1
}

generate_kolla_build_configs () {
  cd $KOLLA_CODE_DIR   || return 1
  tox -e genconfig     || return 1
}

fetch_kolla_container_source () {
  if [[ $SKIP_DL != "" ]]; then return; fi
  cd $KOLLA_CODE_DIR                                                          || return 1
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null                                || return 1
  sudo mkdir -p $NOW_TARBALLS && sudo chown cliff:cliff $NOW_TARBALLS         || return 1
  grep '^#location = .*tar.gz' etc/kolla/kolla-build.conf > $NOW_TARBALLS/locations || return 1
  sed -i 's|^#location = .tarballs_base|wget -P $NOW_TARBALLS https://tarballs.opendev.org|g' $NOW_TARBALLS/locations || return 1
  sed -i 's|^#location = |wget -P $NOW_TARBALLS |g' $NOW_TARBALLS/locations   || return 1
  sed -i "s|\${openstack_branch}|stable-$OS_RELEASE|g" $NOW_TARBALLS/locations   || return 1
  sed -E -i 's/^(wget .*)/\1 || exit 1/g' $NOW_TARBALLS/locations           || return 1
  . $NOW_TARBALLS/locations  || return 1
}

patch_kolla_container_source () {
  # manila_share needs to be patched to not use mon-mgr target (it's an octopus thing, wallaby's not ready for octopus
  # PATCH /registry/kolla_tarballs/wallaby_XXX/manila_debugging/manila-12.0.1.dev15/manila/share/drivers/cephfs/driver.py
  #$UTILITY_DIR/../../files/kolla-manila-driver-patch.py
}

build_kolla_containers () {
  cd $KOLLA_CODE_DIR   || return 1
  cat etc/kolla/kolla-build.conf | sed -E 's/#type = url/type = local/g' |  sed -E "s|^#location = .tarballs_base.*/([^/]*.tar.gz)|location = $NOW_TARBALLS/\1|g" | sed -E "s|^#location = .*/([^/]*.tar.gz)|location = $NOW_TARBALLS/\1|g" > etc/kolla/kolla-build-local.conf
  # kolla will use tag "8" or "stream8" with following base image (for victoria / wallaby)...
  BASE_IMAGE="--base-image $LOCAL_DOCKER_REGISTRY/feralcoder/centos-feralcoder"
  kolla-build -t $INSTALL_TYPE -b centos $BASE_IMAGE --push --registry $LOCAL_DOCKER_REGISTRY -n feralcoder --tag $TAG   --config-file etc/kolla/kolla-build-local.conf $CONTAINER_REGEX || return 1
}

tag_as_latest () {
  # This function strips $LOCAL_DOCKER_REGISTRY/feralcoder/, then adds again
  # This will allow easier repo-renaming and other distribution changes
  for CONTAINER in `docker image list | grep "\-${INSTALL_TYPE}\-" | grep $TAG | grep $CONTAINER_REGEX | awk '{print $1}' | awk -F'/' '{print $(NF)}'`; do
    docker tag $LOCAL_DOCKER_REGISTRY/feralcoder/$CONTAINER:$TAG $LOCAL_DOCKER_REGISTRY/feralcoder/$CONTAINER:$OS_RELEASE-latest              || return 1
    docker push $LOCAL_DOCKER_REGISTRY/feralcoder/$CONTAINER:$OS_RELEASE-latest                             || return 1
    docker tag $LOCAL_DOCKER_REGISTRY/feralcoder/$CONTAINER:$TAG $LOCAL_DOCKER_REGISTRY/feralcoder/$CONTAINER:feralcoder-$OS_RELEASE-latest   || return 1
    docker push $LOCAL_DOCKER_REGISTRY/feralcoder/$CONTAINER:feralcoder-$OS_RELEASE-latest                  || return 1
    docker tag $LOCAL_DOCKER_REGISTRY/feralcoder/$CONTAINER:$TAG $LOCAL_DOCKER_REGISTRY/feralcoder/$CONTAINER:$TAG                || return 1
    docker push $LOCAL_DOCKER_REGISTRY/feralcoder/$CONTAINER:$TAG                               || return 1
  done
}


new_venv kolla                  || fail_exit "new_venv kolla"
use_venv kolla                  || fail_exit "use_venv kolla"
install_packages                || fail_exit "install_packages"
setup_kolla                     || fail_exit "setup_kolla"
generate_kolla_build_configs    || fail_exit "generate_kolla_build_configs"
if [[ ${INSTALL_TYPE,,} == source ]]; then
  fetch_kolla_container_source    || fail_exit "fetch_kolla_container_source"
fi
build_kolla_containers          || fail_exit "build_kolla_containers"
tag_as_latest                   || fail_exit "tag_as_latest"
