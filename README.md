# kolla-ansible
Installing OpenStack via Kolla-Ansible

SETUP:
run: . setup.sh
run: . add_stack_user_everywhere.sh

run: . fix-bonds/bondify_stack.sh

run: . stack_setup_hackery.sh

test inventory: ansible -i inventory-feralstack all -m ping

