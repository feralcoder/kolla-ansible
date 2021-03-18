#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( realpath `dirname $MACRO_SOURCE` )

# BAIL OUT IF USER SOURCES SCRIPT, INSTEAD OF RUNNING IT
if [ ! "${BASH_SOURCE[0]}" -ef "$0" ]; then
  echo "Do not source this script (exits will bail you...)."
  echo "Run it instead"
  return 1
fi

. ~/CODE/feralcoder/host_control/control_scripts.sh

NOW=`date +%Y%m%d-%H%M%S`
KOLLA_ANSIBLE_CHECKOUT=~/CODE/feralcoder/kolla-ansible/
LOG_DIR=~/kolla-ansible-logs/
ANSIBLE_CONTROLLER=dmb

fail_exit () {
  echo; echo "INSTALLATION FAILED AT STEP: $1"
  echo "Check the logs and try again.  Or just give up.  I don't care."
  exit 1
}

boot_to_target () {
  local TARGET=$1
  [[ $TARGET == "admin" ]] || [[ $TARGET == "default" ]] || fail_exit "boot_to_target - target must be 'admin' or 'default'!"

  # Boot all hosts to default / admin
  os_control_boot_to_target_installation_these_hosts $TARGET "$STACK_HOSTS" || exit 1
  ssh_control_wait_for_host_up_these_hosts "$STACK_HOSTS" || exit 1
  os_control_assert_hosts_booted_target $TARGET "$STACK_HOSTS" || {
    echo "All stack hosts must be in their $TARGET OS to install the stack!"
    exit 1
  }
}


take_backups () {
  local BACKUP_NAME=$1

  echo; echo "BOOTING ALL STACK HOSTS TO ADMIN OS FOR BACKUP OPERATION: $STACK_HOSTS"
  boot_to_target admin || exit 1
  echo; echo "BACKING UP STACK_HOSTS $BACKUP_NAME: $STACK_HOSTS"
  backup_control_backup_all $BACKUP_NAME || exit 1
  echo; echo "BOOTING ALL STACK HOSTS TO DEFAULT OS: $STACK_HOSTS"
  boot_to_target default || exit 1
}


# Separate function because I'd like to get this stuff into the base image...
remediate_hosts () {
  ssh_control_run_as_user_these_hosts root "yum -y install telnet" "$STACK_HOSTS"
  ssh_control_run_as_user root "hostname strange.feralcoder.org" str
  ssh_control_run_as_user root "hostnamectl set-hostname strange.feralcoder.org" str
}


setup_for_installers () {
  # Checkout / update kolla-ansible on ansible controller
  echo; echo "CHECKING OUT / UPDATING ~CODE/feralcoder/kolla-ansible ON ANSIBLE_CONTROLLER: $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "cd CODE/feralcoder; [[ -d kolla-ansible ]] || git clone https://feralcoder:`cat ~/.git_password`@github.com/feralcoder/kolla-ansible" $ANSIBLE_CONTROLLER || exit 1
  ssh_control_run_as_user cliff "cd CODE/feralcoder/kolla-ansible; git pull" $ANSIBLE_CONTROLLER || exit 1
  
  # Set up stack user password
  echo; echo "SETTING stack USER PASSWORD ON ANSIBLE_CONTROLLER: $ANSIBLE_CONTROLLER"
  STACKPASSFILE=`ssh_control_get_password ~/.stack_password false` || exit 1
  ssh_control_sync_as_user cliff ~/.stack_password ~/.stack_password $ANSIBLE_CONTROLLER || exit 1
  ssh_control_run_as_user cliff "chmod 600 ~/.stack_password" $ANSIBLE_CONTROLLER || exit 1
  
  # Run: setup-kolla.sh,   make_and_setup_stack_bonds.sh,   test_bonds.sh,   pre-deploy.sh,   deploy-registry.sh
  echo; echo "SETTING UP LOG DIRECTORY $LOG_DIR ON $ANSIBLE_CONTROLLER.  GO THERE FOR PROGRESS OUTPUT."
  ssh_control_run_as_user cliff "mkdir $LOG_DIR" $ANSIBLE_CONTROLLER || exit 1
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/setup-kolla.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/setup-kolla.sh > $LOG_DIR/01-setup-kolla_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 1: Kolla Host Setup"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/make_and_setup_stack_bonds.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/make_and_setup_stack_bonds.sh > $LOG_DIR/02-bonds_setup_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 2: Bond Setup"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/util/test_bonds.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/util/test_bonds.sh > $LOG_DIR/03-test-bonds_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 3: Test Bonds"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/pre-deploy.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/pre-deploy.sh > $LOG_DIR/04-pre-deploy_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 4: Kolla Pre Deployment"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-registry.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-registry.sh > $LOG_DIR/05-deploy-registry_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 5: Registry Deployment"
}


deploy_ceph () {
  # Run: deploy-ceph.sh
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-ceph.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-ceph.sh > $LOG_DIR/06-deploy-ceph_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 6: Deploy Ceph"
}


deploy_kolla () {
  # Run: post-deploy-ceph.sh,  deploy-kolla.sh
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/post-deploy-ceph.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/post-deploy-ceph.sh > $LOG_DIR/07-post-deploy-ceph_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 7: Post-Deploy Ceph"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-kolla.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/deploy-kolla.sh > $LOG_DIR/08-deploy-kolla_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 8: Stack Deployment"
}



# Boot all hosts to default
echo; echo "BOOTING ALL STACK HOSTS TO default OS FOR SETUP: $STACK_HOSTS"
boot_to_target default                  || fail_exit "boot_to_target default"

remediate_hosts                         || fail_exit "remediate_hosts"
setup_for_installers                    || fail_exit "setup_for_installers"
take_backups 02a_Kolla-Ansible_Setup    || fail_exit "take_backups 02a_Kolla-Ansible_Setup"

# ASSUME WE COULD BE STARTING FROM A FREEZE-THAW...
ssh_control_run_as_user cliff "cd CODE/feralcoder/kolla-ansible; git pull" $ANSIBLE_CONTROLLER || fail_exit "git pull kolla-ansible"

deploy_ceph                             || fail_exit "deploy_ceph"
take_backups 02b_Ceph_Setup             || fail_exit "take_backups 02b_Ceph_Setup"
# NEED CEPH EXPORT FUNCTION

# ASSUME WE COULD BE STARTING FROM A FREEZE-THAW...
ssh_control_run_as_user cliff "cd CODE/feralcoder/kolla-ansible; git pull" $ANSIBLE_CONTROLLER || fail_exit "git pull kolla-ansible"

deploy_kolla                            || fail_exit "deploy_kolla"
take_backups 03_Kolla-Ansible_Installed || fail_exit "take_backups 03_Kolla-Ansible_Installed"


