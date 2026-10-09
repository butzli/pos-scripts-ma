#!/bin/bash
# Reproduces Table "tab:esp-send-rate" (Section 6.1): send rate of the IPsec generator without a rate limit,
# by number of cores and by packet size:
# ipsec-gen on pact -> ipsec-sink on stoi with as many receive queues as transmit cores, tunnel mode, AES-256-GCM,
# 8 s per run, flow control and transparent huge pages off (standard setup).
# The data rate is that on the link: ESP frame + 4 bytes CRC + 20 bytes preamble and inter-frame gap.
# "Decrypted" is the share of the packets sent that the receiver decrypted; it is below 100 % where the receiver
# is the slower end.
#   tab-esp-send-rate.sh ["SIZE:CORES ..."]     default: "60:1,2,4,8,16,24,30 256:4,8,16 512:4,8,16 1024:4,8,16 1400:4,8,16"
# Run on coinbase in ~/pos-scripts after ./setup/testbed-setup.sh setup. RAW=file appends the output of all runs to file.
cd ~/pos-scripts
out=$(mktemp)
printf "%-7s %-10s %-6s %-12s %-14s %-12s %s\n" Inner "ESP frame" Cores "Send rate" "Data rate" Sent Decrypted
for v in ${1:-60:1,2,4,8,16,24,30 256:4,8,16 512:4,8,16 1024:4,8,16 1400:4,8,16}; do
	s=${v%%:*}
	for c in $(echo ${v#*:} | tr , " "); do
		./ipsec.sh $c $c $s 8 < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > $out
		[ -n "$RAW" ] && cat $out >> "$RAW"
		esp=$(grep -o "ESP frame [0-9]*" $out | head -1 | grep -o "[0-9]*$")
		sent=$(grep -o "packets sent: [0-9]*" $out | grep -o "[0-9]*$")
		rate=$(grep -o "packets sent: [0-9]*, rate [0-9.]*" $out | grep -o "[0-9.]*$")
		dec=$(grep -o "Total: received [0-9]*, decrypted+authenticated [0-9]*" $out | grep -o "[0-9]*$")
		printf "%-7s %-10s %-6s %-12s %-14s %-12s %s\n" "$s B" "$esp B" $c "$rate Mpps" \
			"$(awk -v r=$rate -v e=$esp 'BEGIN{printf "%.1f Gbit/s", r * (e + 24) * 8 / 1000}')" "$sent" \
			"$(awk -v d=$dec -v n=$sent 'BEGIN{printf "%.2f %%", 100 * d / n}')"
	done
done
rm -f $out
