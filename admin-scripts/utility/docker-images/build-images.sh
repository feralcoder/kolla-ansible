#!/bin/bash
CONTAINER_BUILD_SOURCE="${BASH_SOURCE[0]}"
CONTAINER_BUILD_DIR=$( realpath `dirname $CONTAINER_BUILD_SOURCE` )

. $CONTAINER_BUILD_DIR/../../common.sh
bail_if_sourced
source_host_control_scripts       || fail_exit "source_host_control_scripts"
use_venv kolla-ansible            || fail_exit "use_venv kolla-ansible"



export YUM_REPO_IP=192.168.127.220
DOCKER_LOCAL_REGISTRY=192.168.127.220:4001

NOW=`date +%Y%m%d`
REPOFILE=$CONTAINER_BUILD_DIR/centos-feralcoder/feralcoder.repo
cat $REPOFILE.template | sed "s/<<REPOIP>>/$YUM_REPO_IP/g" > $REPOFILE

for IMAGE in  centos-feralcoder  centos-updated-feralcoder; do
  cd $CONTAINER_BUILD_DIR/$IMAGE  &&  docker build -t $IMAGE .  &&  cd ..
  docker tag $IMAGE $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:feralcoder_$NOW
  docker tag $IMAGE $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:8
  docker tag $IMAGE $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:latest
  docker push $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:feralcoder_$NOW
  docker push $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:8
  docker push $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:latest
done
