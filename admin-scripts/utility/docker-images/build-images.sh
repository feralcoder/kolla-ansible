#!/bin/bash

export YUM_REPO_IP=192.168.127.220

REPOFILE=centos-feralcoder/feralcoder.repo
cat $REPOFILE.template | sed "s/<<REPOIP>>/$YUM_REPO_IP/g" > $REPOFILE

for IMAGE in  centos-feralcoder  centos-updated-feralcoder; do
  cd $IMAGE  &&  docker build -t $IMAGE .  &&  cd ..
done
