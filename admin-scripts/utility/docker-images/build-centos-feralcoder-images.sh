#!/bin/bash
CONTAINER_BUILD_SOURCE="${BASH_SOURCE[0]}"
CONTAINER_BUILD_DIR=$( realpath `dirname $CONTAINER_BUILD_SOURCE` )

. $CONTAINER_BUILD_DIR/../../common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"
use_venv kolla-ansible            || fail_exit "use_venv kolla-ansible"



export YUM_REPO_IP=192.168.127.220
DOCKER_LOCAL_REGISTRY=192.168.127.220:4001

NOW=`date +%Y%m%d`

for RELEASE in 8 stream8; do
  UPDATED_DOCKERFILE=$CONTAINER_BUILD_DIR/centos-updated-feralcoder-$RELEASE/Dockerfile
  cat $UPDATED_DOCKERFILE.template | sed "s/<<REGISTRY>>/$DOCKER_LOCAL_REGISTRY/g" > $UPDATED_DOCKERFILE
  BASE_REPOFILE=$CONTAINER_BUILD_DIR/centos-feralcoder-$RELEASE/feralcoder.repo
  cat $BASE_REPOFILE.template | sed "s/<<REPOIP>>/$YUM_REPO_IP/g" > $BASE_REPOFILE
  for IMAGE in  centos-feralcoder  centos-updated-feralcoder; do
    echo; echo; echo
    cd $CONTAINER_BUILD_DIR/$IMAGE-$RELEASE  &&  docker build -t $IMAGE .  &&  cd ..
    docker tag $IMAGE $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:$RELEASE-$NOW
    docker tag $IMAGE $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:$RELEASE
    docker tag $IMAGE $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:$RELEASE-latest
    docker push $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:$RELEASE-$NOW
    docker push $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:$RELEASE
    docker push $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:$RELEASE-latest
    echo; echo; echo
  done
done
