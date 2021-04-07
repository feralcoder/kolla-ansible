#!/bin/bash

[ "${BASH_SOURCE[0]}" -ef "$0" ]  || { echo "Don't source this script!  Run it."; return 1; }

cd /etc/sysconfig/network-scripts/

IF_NAME=$1
BOND_NAME=$2

IF_CFG=ifcfg-$IF_NAME
BOND_CFG=ifcfg-$BOND_NAME

(grep $BOND_NAME /etc/modprobe.d/bond.conf ) || {
  echo "alias $BOND_NAME bonding" >> /etc/modprobe.d/bond.conf
  echo "options $BOND_NAME mode=balance-rr" >> /etc/modprobe.d/bond.conf
}

[[ -f orig.$IF_CFG ]] || cp $IF_CFG orig.$IF_CFG
cp orig.$IF_CFG $BOND_CFG

sed -i "s/^BOOTPROTO.*/BOOTPROTO=none/g" $IF_CFG
sed -i "s/^NAME.*/NAME=$IF_NAME/g" $IF_CFG
sed -i "s/^ONBOOT.*/ONBOOT=yes/g" $IF_CFG
sed -i "s/^IPV.*//g" $IF_CFG
sed -i "s/^IPADD.*//g" $IF_CFG
sed -i "s/^PREFIX.*//g" $IF_CFG
sed -i "s/^DEFROUTE.*//g" $IF_CFG
sed -i "s/^DNS.*//g" $IF_CFG
sed -i "s/^BROWSER.*//g" $IF_CFG
sed -i "s/^GATEWAY.*//g" $IF_CFG
sed -i "s/^PROXY.*//g" $IF_CFG
sed -i "s/^UUID.*//g" $IF_CFG
echo "MASTER=$BOND_NAME" >> $IF_CFG
echo "SLAVE=yes" >> $IF_CFG
cat $IF_CFG | sort | uniq | grep -v '^$' > IF_$$ && mv -f IF_$$ $IF_CFG

sed -i "s/TYPE=.*/TYPE=BOND/g" $BOND_CFG
sed -i "s/NAME=.*/NAME=$BOND_NAME/g" $BOND_CFG
sed -i "s/^BOOTPROTO.*/BOOTPROTO=none/g" $IF_CFG
sed -i "s/^IPV6.*//g" $BOND_CFG
sed -i "s/^DEVICE.*/DEVICE=$BOND_NAME/g" $BOND_CFG
sed -i "s/^ONBOOT.*/ONBOOT=yes/g" $IF_CFG
echo "BONDING_OPTS='mode=0 miimon=100'" >> $BOND_CFG
echo "BONDING_MASTER=yes" >> $BOND_CFG
cat $BOND_CFG | sort | uniq | grep -v '^$' > IF_$$ && mv -f IF_$$ $BOND_CFG

ifup $BOND_NAME ; sleep 1; ifup $IF_NAME
echo "sleep 2 ; ifdown $IF_NAME; sleep 1; ifup $BOND_NAME ; sleep 3; ifup $IF_NAME" | at now
echo "sleep 10 ; ifup $BOND_NAME ; sleep 3; ifup $IF_NAME" | at now
