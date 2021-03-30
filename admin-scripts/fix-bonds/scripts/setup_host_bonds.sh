#!/bin/bash

[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

cd /etc/sysconfig/network-scripts

cat ifcfg-bond1 | grep 'IP' | sed 's/192.168.127/192.168.40/g' >> ifcfg-bond2
cat ifcfg-bond1 | grep 'IP' | sed 's/192.168.127/172.17.0/g' >> ifcfg-bond3
cat ifcfg-bond1 | grep 'IP' | sed 's/192.168.127/172.18.0/g' >> ifcfg-bond4
cat ifcfg-bond1 | grep 'IP' | sed 's/192.168.127/172.19.0/g' >> ifcfg-bond5
cat ifcfg-bond1 | grep 'IP' | sed 's/192.168.127/172.16.0/g' >> ifcfg-bond6

for x in 2 3 4 5 6; do
  echo PREFIX=24 >> ifcfg-bond$x
  sed -i 's/DEFROUT.*/DEFROUTE=no/g' ifcfg-bond$x
  sed -i 's/BOOTPROTO.*/BOOTPROTO=none/g' ifcfg-bond$x
  sed -i 's/ONBOOT.*/ONBOOT=yes/g' ifcfg-bond$x
  sed -i "s/^GATEWAY.*//g" ifcfg-bond$x
  echo "DEFROUTE=no" >> ifcfg-bond$x

  cat ifcfg-bond$x | sort | uniq | grep -v '^$' > bond_$$ && mv -f bond_$$ ifcfg-bond$x
  echo "ifdown bond$x ; sleep 2; ifup bond$x; sleep 2; ifup bond$x" | at now
done

