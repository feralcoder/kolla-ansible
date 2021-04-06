#!/bin/bash

DEMO_PATH=/registry/docker/local-registry/docker/registry/v2/repositories/feralcoder/
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

REPO_PATH=$1
TAG=$2

REPO_CHECK=`echo $REPO_PATH | awk -F'/' '{print $(NF-3)}'`
[[ $REPO_CHECK == 'v2' ]] || { echo "Bad repo specified, try something like: $DEMO_PATH."; exit 1; }
[[ $TAG != '' ]] || { echo "No tag specified!"; exit 1; }

get_hash () {
  local IMAGE=$1 TAG=$2
  local HASH=`ls $REPO_PATH/$IMAGE/_manifests/tags/$TAG/index/sha256`
  echo $HASH
}


remove_image_tag () {
  local IMAGE=$1 TAG=$2
  #local HASH=`get_hash $IMAGE $TAG`
  ls -d $REPO_PATH/$IMAGE/_manifests/tags/$TAG
}


get_images_with_tag () {
  local TAG=$1
  local IMAGES=`find $REPO_PATH -type d -name $TAG | sed -E 's|.*(/[^/]+/_manifests/).*|\1|g' | awk -F'/' '{print $2}'`
  echo $IMAGES
}

remove_all_this_tag () {
  local TAG=$1
  local IMAGES=`get_images_with_tag $TAG`
  local IMAGE
  for IMAGE in $IMAGES; do
    remove_image_tag $IMAGE $TAG
  done
}


remove_all_this_tag $TAG
