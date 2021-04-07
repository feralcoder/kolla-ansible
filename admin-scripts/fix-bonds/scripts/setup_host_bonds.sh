#!/bin/bash

[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

cd /etc/sysconfig/network-scripts

[[ -f ifcfg-bond2 ]] && cat ifcfg-bond1 | grep 'IP' | sed 's/192.168.127/192.168.40/g' >> ifcfg-bond2
[[ -f ifcfg-bond3 ]] && cat ifcfg-bond1 | grep 'IP' | sed 's/192.168.127/172.17.0/g' >> ifcfg-bond3
[[ -f ifcfg-bond4 ]] && cat ifcfg-bond1 | grep 'IP' | sed 's/192.168.127/172.18.0/g' >> ifcfg-bond4
[[ -f ifcfg-bond5 ]] && cat ifcfg-bond1 | grep 'IP' | sed 's/192.168.127/172.19.0/g' >> ifcfg-bond5
[[ -f ifcfg-bond6 ]] && cat ifcfg-bond1 | grep 'IP' | sed 's/192.168.127/172.16.0/g' >> ifcfg-bond6
[[ -f ifcfg-bond7 ]] && cat ifcfg-bond1 | grep 'IP' | sed 's/192.168.127/192.168.39/g' >> ifcfg-bond7

for x in 2 3 4 5 6 7; do
  [[ -f ifcfg-bond$x ]] || continue
  echo PREFIX=24 >> ifcfg-bond$x
  sed -i 's/DEFROUT.*/DEFROUTE=no/g' ifcfg-bond$x
  sed -i 's/BOOTPROTO.*/BOOTPROTO=none/g' ifcfg-bond$x
  sed -i 's/ONBOOT.*/ONBOOT=yes/g' ifcfg-bond$x
  sed -i "s/^GATEWAY.*//g" ifcfg-bond$x
  echo "DEFROUTE=no" >> ifcfg-bond$x

  cat ifcfg-bond$x | sort | uniq | grep -v '^$' > bond_$$ && mv -f bond_$$ ifcfg-bond$x
  echo "ifdown bond$x ; sleep 2; ifup bond$x; sleep 2; ifup bond$x" | at now
done

