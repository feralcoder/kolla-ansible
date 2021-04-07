#!/bin/bash

ip link add v-lbaas-vlan type veth peer name v-lbaas
ip addr add __IP__ dev v-lbaas
ip link set v-lbaas-vlan up
ip link set v-lbaas up
