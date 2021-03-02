#!/bin/bash

CONTAINER_ID=`docker container list | grep 'docker-registry' | awk '{print $1}'`
docker container stop $CONTAINER_ID
docker container rm $CONTAINER_ID
