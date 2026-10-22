#!/bin/bash
# Reproduces Table "tab:cleartext-send-rate" (Section 6.1): send rate of the cleartext generator by number
# of cores: plain-gen on pact without a rate limit -> plain-sink on stoi with as many flows and receive queues as
# transmit cores, 8 s per run, flow control and transparent huge pages off (standard setup).
# Frame sizes include the CRC; the data rate is that on the link (frame + 20 bytes preamble and inter-frame gap).
# "Received" is the share of the packets sent that the receiver counted in sequence.
#   tab-cleartext-send-rate.sh ["SIZE:CORES ..."]     default: "64:1,2,4,8,12,15,16,24,30 1500:1,2,4,8"
# Prints one CSV line per run in the format of MA/data/tab-cleartext-send-rate.csv.
# Run on coinbase in ~/pos-scripts after ./setup/testbed-setup.sh setup. RAW=file appends the output of all runs to file.
cd ~/pos-scripts
out=$(mktemp)
echo "framesize,cores,mpps,gbit,received"
for v in ${1:-64:1,2,4,8,12,15,16,24,30 1500:1,2,4,8}; do
	f=${v%%:*}
	for c in $(echo ${v#*:} | tr , " "); do
		./cleartext.sh $c $c $((f - 4)) 8 < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > $out
		[ -n "$RAW" ] && cat $out >> "$RAW"
		sent=$(grep -o "Total: sent [0-9]*" $out | grep -o "[0-9]*$")
		rate=$(grep -o "Total: sent [0-9]*, rate [0-9.]*" $out | grep -o "[0-9.]*$")
		ok=$(grep -o "Total: flows [0-9]*, received [0-9]*" $out | grep -o "[0-9]*$")
		awk -v f=$f -v c=$c -v r=$rate -v d=$ok -v n=$sent \
			'BEGIN{printf "%d,%d,%.2f,%.1f,%.2f\n", f, c, r, r * (f + 20) * 8 / 1000, 100 * d / n}'
	done
done
rm -f $out
