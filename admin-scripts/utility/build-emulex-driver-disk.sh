#!/bin/bash
UTILITY_SOURCE="${BASH_SOURCE[0]}"
UTILITY_DIR=$( realpath `dirname $UTILITY_SOURCE` )

. $UTILITY_DIR/../common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"

# FROM: https://bgstack15.wordpress.com/2019/11/28/make-driver-disk-for-centos/
# FROM: https://arrfab.net/posts/2020/Sep/05/remotely-reinstalling-a-node-on-centos-8-with-dud-driver-disk-update-kernel-module-for-nichba/
SUDO_PASS_FILE=~/.password


BUILD_DIR=/home/cliff/build_driver_disk
export IMAGE_ROOT=$BUILD_DIR/dd


setup_for_build () {
  mkdir -p $BUILD_DIR && cd $BUILD_DIR
  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo dnf -y install elrepo-release createrepo squashfs-tools genisoimage
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
  mkdir -p ${IMAGE_ROOT}/rpms/x86_64 ${IMAGE_ROOT}/src
  echo Feralcoder Extra Drivers > ${IMAGE_ROOT}/rhdd3

  pushd ${IMAGE_ROOT}/rpms/x86_64/
  wget http://elrepo.reloumirrors.net/elrepo/el8/x86_64/RPMS/kmod-be2net-12.0.0.0-6.el8_3.elrepo.x86_64.rpm
  createrepo_c ./
#  createrepo -s sha1 --basedir ${IMAGE_ROOT}/rpms/x86_64/ .
  popd
  pushd ${IMAGE_ROOT}/src/
  wget http://elrepo.reloumirrors.net/elrepo/el8/SRPMS/kmod-be2net-12.0.0.0-6.el8_3.elrepo.src.rpm
  popd
#  touch ${IMAGE_ROOT}/.rundepmod
#  ( cd ${IMAGE_ROOT} ;
#     for thisrpm in ${IMAGE_ROOT}/rpms/x86_64/*rpm ;
#     do
#        rpm2cpio ${thisrpm} | cpio -imVd ./lib/*
#     done
#  )
}

write_disk () {
  DRIVER_DISK_DEV=$1
  [[ $DRIVER_DISK_DEV != "" ]] || { echo "Must specify driver disk to write to!  Exiting."; return 1; }
  cd $BUILD_DIR
#  mksquashfs ${IMAGE_ROOT} ./feralcoder-driver-disk.img -noappend
  mkisofs -quiet -lR -V OEMDRV -input-charset utf8 -o feralcoder-drivers.iso ./dd
  rm -rf ${IMAGE_ROOT}

  cat $SUDO_PASS_FILE | sudo -S ls > /dev/null
  sudo dd if=feralcoder-drivers.iso of=$DRIVER_DISK_DEV
}

DRIVER_DISK_DEV=/dev/sdc


setup_for_build
# add_existing_driver_disk /dev/sdX
add_kmod-be2net
write_disk $DRIVER_DISK_DEV
