#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( realpath `dirname $MACRO_SOURCE` )

. $MACRO_DIR/../common.sh
[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

source_host_control_scripts       || fail_exit "source_host_control_scripts"


NOW=`date +%Y%m%d-%H%M%S`
KOLLA_ANSIBLE_CHECKOUT=~/CODE/feralcoder/kolla-ansible/
LOG_DIR=~/kolla-ansible-logs/
ANSIBLE_CONTROLLER=dmb

TWILIO_PAGER_DIR=~/CODE/feralcoder/twilio-pager/


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
  backup_control_backup_these_hosts "$STACK_HOSTS" $BACKUP_NAME || exit 1
  echo; echo "BOOTING ALL STACK HOSTS TO DEFAULT OS: $STACK_HOSTS"
  boot_to_target default || exit 1
}


# Separate function because I'd like to get this stuff into the base image...
remediate_hosts () {
  ssh_control_run_as_user_these_hosts cliff "cd ~/CODE/feralcoder/workstation && git pull" "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts cliff "~/CODE/feralcoder/workstation/update.sh" "$ALL_HOSTS" || return 1

# Captured in 02aHostSetup.sh and 01b_..._REBUILT
#  ssh_control_run_as_user_these_hosts cliff "python3 $TWILIO_PAGER_DIR/pager.py \"hello from \`hostname\`\"" "$STACK_HOSTS"
#
#  ssh_control_run_as_user_these_hosts cliff "( grep 'PATH.*share.bcc.tools' .bash_profile ) && sed -i 's|.*PATH.*share.bcc.tools.*|export PATH=\$PATH:/usr/share/bcc/tools:~cliff/CODE/brendangregg/perf-tools|g' .bash_profile || echo 'export PATH=\$PATH:/usr/share/bcc/tools:~cliff/CODE/brendangregg/perf-tools' >> ~/.bash_profile" "$STACK_HOSTS"
#  ssh_control_run_as_user_these_hosts root "( grep 'PATH.*share.bcc.tools' .bash_profile ) && sed -i 's|.*PATH.*share.bcc.tools.*|export PATH=\$PATH:/usr/share/bcc/tools:~cliff/CODE/brendangregg/perf-tools|g' .bash_profile || echo 'export PATH=\$PATH:/usr/share/bcc/tools:~cliff/CODE/brendangregg/perf-tools' >> ~/.bash_profile" "$STACK_HOSTS"
#
#  ssh_control_run_as_user cliff "rm .local_settings && cd ~/CODE/feralcoder/bootstrap-scripts && ./stack_control.sh" $ANSIBLE_CONTROLLER
  echo
}

postmediate_hosts () {
# Captured in 02aHostSetup.sh and 01b_..._REBUILT
#  TWILIO_PAGER_DIR=~/CODE/feralcoder/twilio-pager/
#  ssh_control_run_as_user_these_hosts root "dnf -y install bcc perf systemtap" "$STACK_HOSTS"
#  ssh_control_run_as_user_these_hosts cliff "mkdir -p ~/CODE/brendangregg && cd ~/CODE/brendangregg && git clone https://github.com/brendangregg/perf-tools.git || ( cd ~/CODE/brendangregg/perf-tools && git pull )" "$STACK_HOSTS"
#
#  ssh_control_run_as_user_these_hosts cliff "cd ~/CODE/feralcoder/ && git clone https://feralcoder:\`cat ~/.git_password\`@github.com/feralcoder/twilio-pager.git" "$STACK_HOSTS"
#  ssh_control_run_as_user_these_hosts cliff "cd $TWILIO_PAGER_DIR && git git pull" "$STACK_HOSTS"
#  for HOST in $STACK_HOSTS; do
#    ssh_control_run_as_user cliff "cd $TWILIO_PAGER_DIR && ./setup.sh" $HOST
#  done
#  ssh_control_run_as_user_these_hosts cliff "python3 $TWILIO_PAGER_DIR/pager.py \"hello from \`hostname\`\"" "$STACK_HOSTS"
  echo
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
  ssh_control_run_as_user cliff "mkdir -p $LOG_DIR" $ANSIBLE_CONTROLLER || exit 1
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/01-setup-kolla.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/01-setup-kolla.sh > $LOG_DIR/01-setup-kolla_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 1: Kolla Host Setup"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/make_and_setup_stack_bonds.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/make_and_setup_stack_bonds.sh > $LOG_DIR/02a-bonds_setup_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 2a: Bond Setup"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/util/test_bonds.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/fix-bonds/util/test_bonds.sh > $LOG_DIR/02b-test-bonds_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 2b: Test Bonds"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/03-deploy-registry.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/03-deploy-registry.sh > $LOG_DIR/03-deploy-registry_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 3: Registry Deployment"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/04a-pre-deploy.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/04a-pre-deploy.sh > $LOG_DIR/04a-pre-deploy_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 4a: Kolla Pre Deployment"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/04b-container-setup.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/04b-container-setup.sh > $LOG_DIR/04b-container-setup_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 4b: Container Setup"
}


deploy_ceph () {
  # Run: deploy-ceph.sh
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/05-deploy-ceph.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/05-deploy-ceph.sh > $LOG_DIR/05-deploy-ceph_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 5: Deploy Ceph"
}


deploy_kolla () {
  # Run: post-deploy-ceph.sh,  deploy-kolla.sh
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/06-post-deploy-ceph.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/06-post-deploy-ceph.sh > $LOG_DIR/06-post-deploy-ceph_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 6: Post-Deploy Ceph"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/07-deploy-kolla.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/07-deploy-kolla.sh > $LOG_DIR/07-deploy-kolla_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 7: Stack Deployment"
}


post_deploy_kolla () {
  # Run: post-deploy-kolla.sh
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/08a-post-deploy-kolla.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/08a-post-deploy-kolla.sh > $LOG_DIR/08a-post-deploy-kolla_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 8a: Post-Deploy Kolla"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/08a-pubnet1-setup.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/08a-pubnet1-setup.sh > $LOG_DIR/08a-pubnet1-setup_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 8a: Pubnet1 Setup"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/08b-octavia-setup.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/08b-octavia-setup.sh > $LOG_DIR/08b-octavia-setup.sh_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 8b: Post-Deploy Octavia"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/08c-config-fixes.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/08c-config-fixes.sh > $LOG_DIR/08c-config-fixes.sh_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 8c: Config Fixes"
  echo; echo "EXECUTING $KOLLA_ANSIBLE_CHECKOUT/admin-scripts/09a-setup-feralstack.sh ON $ANSIBLE_CONTROLLER"
  ssh_control_run_as_user cliff "$KOLLA_ANSIBLE_CHECKOUT/admin-scripts/09a-setup-feralstack.sh > $LOG_DIR/09a-setup-feralstack.sh_$NOW.log 2>&1" $ANSIBLE_CONTROLLER || fail_exit "Step 9a: Setup Feralstack"
}





# Boot all hosts to default
echo; echo "BOOTING ALL STACK HOSTS TO default OS FOR SETUP: $STACK_HOSTS"
boot_to_target default                            || fail_exit "boot_to_target default"

remediate_hosts                                   || fail_exit "remediate_hosts"
take_backups 01c_CentOS_8_3_Remediated            || fail_exit "take_backups 01c_CentOS_8_3_Remediated.sh"

# ASSUME WE COULD BE STARTING FROM A FREEZE-THAW...
ssh_control_run_as_user cliff "cd CODE/feralcoder/kolla-ansible; git pull" $ANSIBLE_CONTROLLER || fail_exit "git pull kolla-ansible"

#postmediate_hosts                                 || fail_exit "postmediate_hosts"
#take_backups 01d_CentOS_8_3_Postmediated          || fail_exit "take_backups 01d_CentOS_8_3_Postmediated.sh"
setup_for_installers                              || fail_exit "setup_for_installers"
take_backups 02a_Kolla-Ansible_Setup              || fail_exit "take_backups 02a_Kolla-Ansible_Setup"

# ASSUME WE COULD BE STARTING FROM A FREEZE-THAW...
ssh_control_run_as_user cliff "cd CODE/feralcoder/kolla-ansible; git pull" $ANSIBLE_CONTROLLER || fail_exit "git pull kolla-ansible"

deploy_ceph                                       || fail_exit "deploy_ceph"
#take_backups 02b_Ceph_Setup                       || fail_exit "take_backups 02b_Ceph_Setup"
# NEED CEPH EXPORT FUNCTION

# ASSUME WE COULD BE STARTING FROM A FREEZE-THAW...
ssh_control_run_as_user cliff "cd CODE/feralcoder/kolla-ansible; git pull" $ANSIBLE_CONTROLLER || fail_exit "git pull kolla-ansible"

deploy_kolla                                      || fail_exit "deploy_kolla"
post_deploy_kolla                                 || fail_exit "post_deploy_kolla"
#take_backups 03_Kolla-Ansible_Installed           || fail_exit "take_backups 03_Kolla-Ansible_Installed"


