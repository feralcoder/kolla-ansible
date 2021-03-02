#!/bin/bash

docker run -d \
 --name docker-registry \
 --restart=always \
 -p 4000:5000 \
 -v /registry/docker:/var/lib/registry \
 -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
 registry:2

