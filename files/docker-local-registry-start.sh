#!/bin/bash

docker run -d \
 --name docker-local-registry \
 --restart=always \
 -p 4001:5000 \
 -v /registry/docker/local-registry:/var/lib/registry \
 registry:2

