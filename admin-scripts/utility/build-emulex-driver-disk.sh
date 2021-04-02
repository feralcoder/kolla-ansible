#!/bin/bash
UTILITY_SOURCE="${BASH_SOURCE[0]}"
UTILITY_DIR=$( realpath `dirname $UTILITY_SOURCE` )

. $UTILITY_DIR/../common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"

# FROM: https://bgstack15.wordpress.com/2019/11/28/make-driver-disk-for-centos/
SUDO_PASS_FILE=~/.password


BUILD_DIR=/home/cliff/build_driver_disk
export SQUASH_ROOT=$BUILD_DIR/squashfs-root


setup_for_build () {
  mkdir -p $BUILD_DIR && cd $BUILD_DIR
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo dnf -y install elrepo-release createrepo squashfs-tools
}

add_existing_driver_disk () {
  DRIVER_DISK_DEV=$1
  [[ $DRIVER_DISK_DEV != "" ]] || { echo "Must specify existing driver disk!  Exiting."; return 1; }
  cd $BUILD_DIR
  dd if=$DRIVER_DISK_DEV of=existing.img
  unsquashfs -f -d ./ existing.img
}

add_kmod-be2net () {
  cd $BUILD_DIR
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo dnf -y download kmod-be2net

  mkdir -p ${SQUASH_ROOT}/rpms/x86_64
  echo Feralcoder Extra Drivers > ${SQUASH_ROOT}/rhdd3
  cp -p *rpm ${SQUASH_ROOT}/rpms/x86_64/
  createrepo --basedir ${SQUASH_ROOT}/rpms/x86_64/ .
  touch ${SQUASH_ROOT}/.rundepmod
  ( cd ${SQUASH_ROOT} ;
     for thisrpm in ${SQUASH_ROOT}/rpms/x86_64/*rpm ;
     do
        rpm2cpio ${thisrpm} | cpio -imVd ./lib/*
     done
  )
}

write_disk () {
  DRIVER_DISK_DEV=$1
  [[ $DRIVER_DISK_DEV != "" ]] || { echo "Must specify driver disk to write to!  Exiting."; return 1; }
  cd $BUILD_DIR
  mksquashfs ${SQUASH_ROOT} ./feralcoder-driver-disk.img
  rm -rf ${SQUASH_ROOT}

  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo dd if=feralcoder-driver-disk.img of=$DRIVER_DISK_DEV
}




setup_for_build
# add_existing_driver_disk /dev/sdX
add_kmod-be2net
write_disk $DRIVER_DISK_DEV
