#!/bin/bash
set -euxo pipefail

ifconfig eth0 10.0.2.15 up
route add default gw 10.0.2.2
ifconfig lo up
mkdir -p /mnt/share
mount -t 9p share /mnt/share -omsize=52428800
/etc/init.d/ssh start
