#!/bin/bash
# https://github.com/kmonticolo/proxmox

# get an IP ov VM

NAME=$1

if [ -z $1 ]; then {
  echo "usage `basename $0` <vm_name>"
  exit 1
}
fi

VMID=$(qm list|grep -w $NAME| awk '{print $1}')
if [ -z $VMID ]; then {
  echo "No such vm name"
  exit 2
}
fi

MAC=$(qm config $VMID |grep net |sed -e 's/^.*virtio=//' -e 's/,.*$//' | tr [:upper:] [:lower:])
if [ -z $MAC ]; then {
  echo "Cannot get MAC address for $NAME"
  exit 3
}
fi

IP=$( arp-scan -I vmbr0 192.168.1.0/24|grep $MAC |awk '{ print $1 }')
if [ -z $IP ]; then {
  echo "Cannot get IP address for $NAME"
  exit 4
}
fi

echo $IP

