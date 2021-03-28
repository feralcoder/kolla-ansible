#!/bin/bash

export YUM_REPO_IP=192.168.127.220
DOCKER_LOCAL_REGISTRY=192.168.127.220:4001

NOW=`date +%Y%m%d`
REPOFILE=centos-feralcoder/feralcoder.repo
cat $REPOFILE.template | sed "s/<<REPOIP>>/$YUM_REPO_IP/g" > $REPOFILE

for IMAGE in  centos-feralcoder  centos-updated-feralcoder; do
  cd $IMAGE  &&  docker build -t $IMAGE .  &&  cd ..
  docker tag $IMAGE $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:feralcoder_$NOW
  docker tag $IMAGE $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:latest
  docker push $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:feralcoder_$NOW
  docker push $DOCKER_LOCAL_REGISTRY/feralcoder/$IMAGE:latest
done
