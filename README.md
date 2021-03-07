# kolla-ansible
Installing OpenStack via Kolla-Ansible


OVERVIEW:
These scripts are built on this environment setup:

Hosts Environment:
- admin box:             yoda
- deployment controller: dumbledore
- openstack servers:     OS control and OS compute nodes
- openstack control:     strange, merlin, gandalf
- openstack compute:     kerrigan, neo, bowman, lawnmowerman, manhattan

The admin box is outside of the whole stack deployment, and is used to run scripts which can backup and restore the deployment controller.

- Bob Korbuszewski
- Bob Smith
- Hannah Korbuszewski
- Stacey Korbuszewski
- Leanne Korbuszewski
- Lisa Smith
- Lisa Korbuszewski
- Hannah Smith
- Stacey Smith
- Leanne Smith

The deployment controller is the main workhorse for the deployment.  This is the ansible controller, the backup server, the repo server, and container registry.

The openstack nodes are all ephemeral between deployments.  Kolla-Ansible does expect a significant amount of the setup to be done before running, including prerequisite packages and network setup.



Networks:
In theory each host should be configurable in ansible to allow different interface naming schemes to be supported between nodes.
In reality, this doesn't work.  My solution is to make a single-nic bond on each interface so consistent ordered bond names may be used in configs.
- bond1: network          (before any extra config, default net for everything)
- bond2: neutron_external (home for world-facing VIPs and floating IPs)
- bond3: api_interface    (system communications between openstack components)
- bond4: storage          (swift storage traffic)
- bond5: swift storage    (replication, control, and traffic between storage nodes)
- bond6: tunnel           (tunnels between nodes for customer networks)



ADMIN SCRIPTS:
From a very high level, the admin-scripts are meant to do everything everything.
- Take nodes from base-OS install to a ready state for deployment.
- Configure bonds onto interfaces to map right into my kolla-ansible configuration.
- Backup and restore any / every node before, during, and after deployments.
- Stop and start the stack, including power on / off./stnha

These scripts are located in .../kolla-ansible/admin-scripts/
- setup.sh:                      Performs all user and package-related setup tasks, plus git/key/hostname setup
- make_and_setup_stack_bonds.sh: Converts interfaces into a consistently named set of bonds, with stack IPs.



PREREQ'S:
The admin scripts above handle these prerequisites.
These are prerequisites before the kolla-ansible supplied scripts may be run.

Environment is fully set up with host_control administration:

  From admin server:
  - git_control_pull_push_these_hosts "$ALL_HOSTS"
  
  On every server:
  for host in $ALL_SERVERS; do
     ssh_control_run_as_user cliff "ilo_control_refetch_ilo_hostkey_these_hosts \"$ALL_HOSTS\"" $HOST
     ssh_control_run_as_user cliff "ssh_control_refetch_hostkey_these_hosts \"$ALL_HOSTS\"" $HOST
     ssh_control_run_as_user cliff "ssh_control_refetch_hostkey_these_hosts \"$ALL_HOSTS_API_NET\"" $HOST
     ssh_control_run_as_user cliff "./CODE/feralcoder/workstation/update.sh" $HOST                    # Set up /etc/hosts
     ssh_control_run_as_user root "( hostname | grep -vE '^[^\.]+-api' ) && \
                                   { hostname \`hostname | sed -E 's/^([^\.]+)/\1-api/g'\` > /dev/null; \
                                   hostname ; } || echo hostname is already apid" $HOST
  done




SETUP:
Again, these steps are handled by the admin scripts mentioned above.

Run: 
  . setup.sh
  . fix-bonds/bondify_stack.sh
  . deploy.sh
