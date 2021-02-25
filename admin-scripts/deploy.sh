#!/bin/bash

kolla-ansible -i ./inventory-feralstack bootstrap-servers
kolla-ansible -i ./inventory-feralstack prechecks
kolla-ansible -i ./inventory-feralstack deploy
