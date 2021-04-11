#!/bin/bash

ip link add v-__NETNAME__-vlan type veth peer name v-__NETNAME__
ip addr add __IP__ dev v-__NETNAME__
ip link set v-__NETNAME__-vlan up
ip link set v-__NETNAME__ up
