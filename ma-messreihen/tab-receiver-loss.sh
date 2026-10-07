#!/bin/bash
# Reproduces Table "tab:receiver-loss" (Section 6.3): packets dropped because a receive queue of stoi was full,
# with receive queues of 512 and of 4,096 descriptors, two runs each. pact -> stoi, 60-byte packets, 30 s.
# The columns "with reserved cores" are what this script measures after ./setup/testbed-setup.sh setup; for the column
# "without", delete the boot parameters first
# (pos nodes bootparameter -d NODE isolcpus nohz_full rcu_nocbs irqaffinity psi), reset and set up the nodes again.
# Run on coinbase in ~/pos-scripts. RAW=file appends the output of all runs to file.
cd ~/pos-scripts
out=$(mktemp)
echo "kernel of stoi: $(pos commands launch -v stoi -- cat /sys/devices/system/cpu/isolated 2>/dev/null | tail -1 | sed 's/^$/no reserved cores/; s/^[0-9]/reserved CPUs &/')"
printf "%-34s %-6s %-12s %s\n" Run Ring Sent Dropped
for d in 512 4096; do
	for i in 1 2; do
		./ipsec.sh 4 4 60 30 "" "--rx-descs $d" "-r 10" < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > $out
		[ -n "$RAW" ] && cat $out >> "$RAW"
		sent=$(grep -o "packets sent: [0-9]*" $out | grep -o "[0-9]*$")
		drop=$(grep -o "queue was full [0-9]*" $out | grep -o "[0-9]*$")
		printf "%-34s %-6s %-12s %s\n" "IPsec, 4 SAs, 10 Mpps, 30 s" $d "$sent" "$drop"
		./cleartext.sh 4 4 60 30 "-r 6" "--rss --rx-descs $d" < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > $out	# RSS as in the measurement of the table
		[ -n "$RAW" ] && cat $out >> "$RAW"
		sent=$(grep -o "Total: sent [0-9]*" $out | grep -o "[0-9]*$")
		drop=$(grep -o "queue was full [0-9]*" $out | grep -o "[0-9]*$")
		printf "%-34s %-6s %-12s %s\n" "cleartext, 4 flows, 6 Mpps, 30 s" $d "$sent" "$drop"
	done
done
rm -f $out
