#!/bin/bash



udevfile='/etc/udev/rules.d/70-persistent-net.rules'
line=$(tail -1 $udevfile)
macaddress=`echo $line | grep -E -o '([0-9a-z]{2}:){5}[0-9a-z]{2}'`
echo "$line" | sed -e 's/NAME=\"eth[0-9]*\"/NAME=\"eth0\"/' > $udevfile
ifcfgpath=' /etc/sysconfig/network-scripts/ifcfg-eth0'
cat > $ifcfgpath <<EOF
DEVICE=eth0
HWADDR=$macaddress
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=yes
BOOTPROTO=dhcp
EOF
service network restart



