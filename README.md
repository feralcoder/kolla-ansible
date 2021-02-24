# kolla-ansible
Installing OpenStack via Kolla-Ansible

SETUP:
run: . setup.sh
run: . add_stack_user_everywhere.sh
test inventory: ansible -i inventory-feralstack all -m ping
