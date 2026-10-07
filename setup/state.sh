#!/bin/bash
# state of a node: MoonGen version, kernel boot parameters, transparent huge pages, flow control of the ConnectX ports
cd /root/MoonGen && git log --oneline -1 && git -C libmoon log --oneline -1
echo "transceiver: $(md5sum examples/ipsec/ipsec-transceiver.lua | cut -c1-32), ramp lines: $(grep -c ramping examples/ipsec/ipsec-transceiver.lua)"
echo "cmdline: $(tr " " "\n" < /proc/cmdline | grep -E "isolcpus|nohz_full|rcu_nocbs|irqaffinity|psi|transparent" | tr "\n" " ")"
echo "THP: $(cat /sys/kernel/mm/transparent_hugepage/enabled)"
for i in /sys/class/net/*; do
	[ "$(basename "$(readlink -f $i/device/driver)")" = mlx5_core ] && echo "${i##*/}: $(ethtool -a ${i##*/} | grep -E "^RX|^TX" | tr -s "\n\t" " ")"
done
