# kolla-ansible
Installing OpenStack via Kolla-Ansible



PREREQ'S:
Environment is fully set up with host_control administration.

From admin server:
- git_control_pull_push_these_hosts "$ALL_HOSTS"

On every server:
for host in $ALL_SERVERS; do
   ssh_control_run_as_user cliff "ilo_control_refetch_ilo_hostkey_these_hosts \"$ALL_HOSTS\"" $HOST
   ssh_control_run_as_user cliff "ssh_control_refetch_hostkey_these_hosts \"$ALL_HOSTS\"" $HOST
   ssh_control_run_as_user cliff "ssh_control_refetch_hostkey_these_hosts \"$ALL_HOSTS_API_NET\"" $HOST
   ssh_control_run_as_user cliff "./CODE/feralcoder/workstation/update.sh" $HOST                    # Set up /etc/hosts
   ssh_control_run_as_user root "( hostname | grep -vE '^[^\.]+-api' ) && { hostname \`hostname | sed -E 's/^([^\.]+)/\1-api/g'\` > /dev/null; hostname ; } || echo hostname is already apid" $HOST
done

SETUP:
run: . setup.sh
run: . add_stack_user_everywhere.sh

run: . fix-bonds/bondify_stack.sh

run: . stack_setup_hackery.sh

test inventory: ansible -i inventory-feralstack all -m ping

run: . deploy.sh

Bond interfaces may become unconfigured, more experience is needed to determine onset and causes.
For now: run fix_bonds/start_bond_ifs.sh when the bonds become inactive.
