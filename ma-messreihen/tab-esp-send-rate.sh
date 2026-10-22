#!/bin/bash
# Reproduces Table "tab:esp-send-rate" (Section 6.1): send rate of the IPsec generator without a rate limit,
# by number of cores and by packet size:
# ipsec-gen on pact -> ipsec-sink on stoi with as many receive queues as transmit cores, tunnel mode, AES-256-GCM,
# 8 s per run, flow control and transparent huge pages off (standard setup).
# The run scripts rotate the performance counters of the transmit cores at the start (pmu-rotate.sh), as in the thesis.
# The ESP frame is given with the CRC; the data rate is that on the link (ESP frame + 20 bytes preamble and
# inter-frame gap). "Decrypted" is the share of the packets sent that the receiver decrypted, in %; it is below 100
# where the receiver is the slower end.
#   tab-esp-send-rate.sh ["SIZE:CORES ..."]     default: "60:1,2,4,8,12,15,16,24,30 256:4,8,16 512:4,8,16 1024:4,8,16 1400:4,8,16"
# Prints one CSV line per run in the format of MA/data/tab-esp-send-rate.csv.
# Run on coinbase in ~/pos-scripts after ./setup/testbed-setup.sh setup. RAW=file appends the output of all runs to file.
cd ~/pos-scripts
out=$(mktemp)
echo "innersize,espframe,cores,mpps,gbit,decrypted"
for v in ${1:-60:1,2,4,8,12,15,16,24,30 256:4,8,16 512:4,8,16 1024:4,8,16 1400:4,8,16}; do
	s=${v%%:*}
	for c in $(echo ${v#*:} | tr , " "); do
		./ipsec.sh $c $c $s 8 < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > $out
		[ -n "$RAW" ] && cat $out >> "$RAW"
		esp=$(grep -o "ESP frame [0-9]*" $out | head -1 | grep -o "[0-9]*$")
		sent=$(grep -o "packets sent: [0-9]*" $out | grep -o "[0-9]*$")
		rate=$(grep -o "packets sent: [0-9]*, rate [0-9.]*" $out | grep -o "[0-9.]*$")
		dec=$(grep -o "Total: received [0-9]*, decrypted+authenticated [0-9]*" $out | grep -o "[0-9]*$")
		# decrypted as in the thesis: 100, two decimals above 99.9, otherwise one
		awk -v s=$s -v e=$((esp + 4)) -v c=$c -v r=$rate -v d=$dec -v n=$sent 'BEGIN{p = 100 * d / n
			v = (d == n) ? "100" : sprintf((p > 99.9) ? "%.2f" : "%.1f", p)
			printf "%d,%d,%d,%.2f,%.1f,%s\n", s, e, c, r, r * (e + 20) * 8 / 1000, v}'
	done
done
rm -f $out
