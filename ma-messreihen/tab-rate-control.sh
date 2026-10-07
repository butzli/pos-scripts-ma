#!/bin/bash
# Reproduces Table "tab:rate-control" (Section 6.3): requested and achieved send rates with the option -r.
# pact -> stoi, eight cores and eight receive queues, 60-byte packets, 30 s. The run without a limit is repeated
# three times, because its rate varies between runs.
# The achieved rate is the one the generator reports at the end; a warning means a core missed its share by > 1 %.
# Run on coinbase in ~/pos-scripts after ./setup/testbed-setup.sh setup. RAW=file appends the output of all runs to file.
cd ~/pos-scripts
out=$(mktemp)
printf "%-10s %-10s %-11s %-8s %s\n" Generator Requested Achieved Warning "Dropped (queue full)"
for g in ipsec cleartext; do
	for r in 20 40 60 70 80 0 0 0; do
		x=$([ $r = 0 ] || echo "-r $r")
		if [ $g = ipsec ]; then ./ipsec.sh 8 8 60 30 "" "" "$x"; else ./cleartext.sh 8 8 60 30 "$x"; fi < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > $out
		[ -n "$RAW" ] && cat $out >> "$RAW"
		rate=$(grep -o -E "(packets sent:|Total: sent) [0-9]*, rate [0-9.]*" $out | grep -o "[0-9.]*$")
		warn=$(grep -c "reached only" $out)
		drop=$(grep -o "queue was full [0-9]*" $out | grep -o "[0-9]*$")
		printf "%-10s %-10s %-11s %-8s %s\n" $g "$([ $r = 0 ] && echo unlimited || echo "$r Mpps")" "$rate Mpps" $([ "$warn" -gt 0 ] && echo yes || echo no) "$drop"
	done
done
rm -f $out
