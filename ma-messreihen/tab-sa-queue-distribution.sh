#!/bin/bash
# Reproduces Table "tab:sa-queue-distribution" (Section 6.3): assignment of SAs to receive queues by RSS
# and by one flow rule per SPI. pact -> stoi, tunnel mode, AES-256-GCM, 60-byte inner packets, 30 s.
# The sender is limited to a fixed rate per SA, so that both assignments are offered the same load:
# 7 Mpps per SA, and 4 Mpps per SA with 16 SAs (two SAs then fit on one receive queue).
# Run on coinbase in ~/pos-scripts after ./setup/testbed-setup.sh setup. RAW=file appends the output of all runs to file.
cd ~/pos-scripts
out=$(mktemp)
printf "%-4s %-7s %-11s %-10s %-11s %-11s %-11s %-12s %s\n" SAs Queues Assignment Offered Sent Decrypted Dropped "Queues used" Warning
for v in "2 2 7" "4 4 7" "8 8 7" "16 8 4"; do
	set -- $v; n=$1; q=$2; r=$(($1 * $3))
	for a in --rss ""; do
		./ipsec.sh $n $q 60 30 "" "$a" "-r $r" < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > $out
		[ -n "$RAW" ] && cat $out >> "$RAW"
		sent=$(grep -o "packets sent: [0-9]*" $out | grep -o "[0-9]*$")
		dec=$(grep -o "Total: received [0-9]*, decrypted+authenticated [0-9]*" $out | grep -o "[0-9]*$")
		used=$(grep -o "Queue [0-9]*: SPI" $out | sort -u | wc -l)	# -o: the lines of two tasks can end up on one line
		drop=$(grep -o "queue was full [0-9]*" $out | grep -o "[0-9]*$")
		warn=$(grep -c "reached only" $out)
		printf "%-4s %-7s %-11s %-10s %-11s %-11s %-11s %-12s %s\n" $n $q "${a:-flow rules}" "$r Mpps" "$sent" "$dec" "$drop" $used $([ "$warn" -gt 0 ] && echo yes || echo no)
	done
done
rm -f $out
