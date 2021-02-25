#!/bin/bash

cd /etc/sysconfig/network-scripts/

IF_NAME=$1
BOND_NAME=$2

FIRST_IF=ifcfg-$IF_NAME
FIRST_BOND=ifcfg-$BOND_NAME
cp $FIRST_IF $FIRST_BOND

echo "alias $BOND_NAME bonding" >> /etc/modprobe.d/bond.conf
echo "options $BOND_NAME mode=balance-rr" >> /etc/modprobe.d/bond.conf


sed -i "s/^BOOTPROTO.*/BOOTPROTO=none/g" $FIRST_IF
sed -i "s/^NAME.*/NAME=$IF_NAME/g" $FIRST_IF
sed -i "s/^ONBOOT.*/ONBOOT=yes/g" $FIRST_IF
sed -i "s/^IPV.*//g" $FIRST_IF
sed -i "s/^IPADD.*//g" $FIRST_IF
sed -i "s/^PREFIX.*//g" $FIRST_IF
sed -i "s/^DEFROUTE.*//g" $FIRST_IF
sed -i "s/^DNS.*//g" $FIRST_IF
sed -i "s/^BROWSER.*//g" $FIRST_IF
sed -i "s/^GATEWAY.*//g" $FIRST_IF
sed -i "s/^PROXY.*//g" $FIRST_IF
sed -i "s/^UUID.*//g" $FIRST_IF
echo "MASTER=$BOND_NAME" >> $FIRST_IF
echo "SLAVE=yes" >> $FIRST_IF
cat $FIRST_IF | sort | grep -v '^$' > IF_$$ && mv -f IF_$$ $FIRST_IF

sed -i "s/TYPE=.*/TYPE=BOND/g" $FIRST_BOND
sed -i "s/NAME=.*/NAME=$BOND_NAME/g" $FIRST_BOND
sed -i "s/^BOOTPROTO.*/BOOTPROTO=none/g" $FIRST_IF
sed -i "s/^IPV6.*//g" $FIRST_BOND
sed -i "s/^DEVICE.*/DEVICE=$BOND_NAME/g" $FIRST_BOND
sed -i "s/^ONBOOT.*/ONBOOT=yes/g" $FIRST_IF
echo "BONDING_OPTS='mode=0 miimon=100'" >> $FIRST_BOND
echo "BONDING_MASTER=yes" >> $FIRST_BOND
cat $FIRST_BOND | sort | uniq | grep -v '^$' > IF_$$ && mv -f IF_$$ $FIRST_BOND


ifup $BOND_NAME ; ifup $IF_NAME
sleep 5
ifup $BOND_NAME ; ifup $IF_NAME

# LIST WITH:
# nmcli c

