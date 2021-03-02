#!/bin/bash

docker run -d \
 --name registry \
 --restart=always \
 -p 4000:5000 \
 -v registry:/registry/docker \
 -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
 registry:2

