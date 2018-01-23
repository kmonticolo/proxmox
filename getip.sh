#!/bin/bash
# https://github.com/kmonticolo/proxmox

# get an IP ov VM
INTERFACE="vmbr0"
SUBNET="192.168.1.0/24"

NAME=$1

if [ -z $1 ]; then {
  echo "usage `basename $0` <vm_name>"
  exit 1
}
fi

VMID=$(/usr/sbin/qm list|grep -w $NAME| awk '{print $1}')
if [ -z $VMID ]; then {
  echo "No such vm name"
  exit 2
}
fi

MAC=$(/usr/sbin/qm config $VMID |grep net |sed  -e 's/,.*$//' -e 's/^.*=//' | tr [:upper:] [:lower:])
if [ -z $MAC ]; then {
  echo "Cannot get MAC address for $NAME"
  exit 3
}
fi

ARPSCAN=$(/usr/bin/which arp-scan)
if [ -z $ARPSCAN ]; then {
  echo "No arp-scan binary found"
  exit 4
}
fi

IP=$(${ARPSCAN} -I ${INTERFACE} ${SUBNET} |grep $MAC |awk '{ print $1 }')
if [ -z $IP ]; then {
  echo "Cannot get IP address for $NAME"
  exit 5
}
fi

echo $IP

