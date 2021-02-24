# kolla-ansible
Installing OpenStack via Kolla-Ansible

SETUP:
run: . setup.sh
run: . add_stack_user_everywhere.sh

run: . fix-bonds/bondify_stack.sh

run: . stack_setup_hackery.sh

test inventory: ansible -i inventory-feralstack all -m ping

run: . deploy.sh

Bond interfaces may become unconfigured, more experience is needed to determine onset and causes.
For now: run fix_bonds/start_bond_ifs.sh when the bonds become inactive.
