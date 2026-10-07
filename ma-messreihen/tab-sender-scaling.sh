#!/bin/bash
# Reproduces Table "tab:sender-scaling" (Appendix A.3): send rate of pact by number of cores.
# Flow udp-load via moongen-simple, 5 s per run, flow control disabled, no DPDK receiver on stoi;
# "arrived" is the difference of the hardware counter rx_packets_phy of stoi. Small frames use a copy of the
# flow with a wide range of UDP ports (flows-rss), large frames the same with pktLength = 1496 (flows-big).
# The data rate printed is MoonGen's "with framing" figure.
# Run on coinbase after ./setup/testbed-setup.sh setup.
for n in pact stoi; do ssh $n "ethtool -A ens4f1np1 rx off tx off" 2>/dev/null; done
ssh pact 'cd /root/MoonGen && rm -rf flows-rss flows-big && cp -r flows flows-rss &&
	sed -i "s/range(1234, 1245)/range(1024, 9000)/" flows-rss/udp-load.lua &&
	cp -r flows-rss flows-big && sed -i "s/pktLength = 60/pktLength = 1496/" flows-big/udp-load.lua' 2>/dev/null
phy() { ssh stoi 'ethtool -S ens4f1np1 | grep " rx_packets_phy"' 2>/dev/null | grep -o "[0-9]*$"; }
printf "%-8s %-6s %-12s %-16s %-12s %s\n" Frame Cores "Packet rate" "Data rate" Sent Arrived
for run in "64 flows-rss 1 2 4 8 16 24 30" "1500 flows-big 1 2 4 8"; do
	set -- $run; size=$1; dir=$2; shift 2
	for c in "$@"; do
		ports=$(printf "1,%.0s" $(seq $c)); a=$(phy)
		line=$(ssh pact "cd /root/MoonGen && ./moongen-simple start -c $dir udp-load:${ports%,}::timeLimit=5s 2>&1" 2>/dev/null | grep "id=1\] TX.*total" | tail -1)
		b=$(phy)
		printf "%-8s %-6s %-12s %-16s %-12s %s\n" "$size B" $c \
			"$(echo "$line" | sed -E 's/.*: ([0-9.]+) \(StdDev.*/\1 Mpps/')" \
			"$(echo "$line" | sed -E 's/.*\(([0-9]+) Mbit\/s with framing\).*/\1 Mbit\/s/')" \
			"$(echo "$line" | sed -E 's/.*total ([0-9]+) packets.*/\1/')" $((b - a))
	done
done
for n in pact stoi; do ssh $n "ethtool -A ens4f1np1 rx on tx on" 2>/dev/null; done
