#!/bin/bash
# Size of the receive queues at full load (Section 5.3, sec:receiver-loss): rate that stoi takes from pact without
# a rate limit, with 512 and with 4,096 descriptors per receive queue, alternating, 8 s per run, 60-byte packets,
# standard setup. IPsec: ipsec-gen -> ipsec-sink with as many SAs and queues as cores; cleartext: plain-gen ->
# plain-sink, 4 flows on 4 queues. The rate taken is the send rate times the share of the packets sent that was
# decrypted (IPsec) or received in sequence (cleartext).
#   tab-rx-descs.sh ["IPSEC-CORES"] [RUNS]      default: "8 16 30" 3
# Run on coinbase in ~/pos-scripts after ./setup/testbed-setup.sh setup. RAW=file appends the output of all runs to file.
cd ~/pos-scripts
out=$(mktemp)
printf "%-10s %-6s %-6s %-12s %s\n" Traffic Cores Descs "Send rate" Taken
for i in $(seq ${2:-3}); do
	for d in 512 4096; do
		for c in ${1:-8 16 30}; do
			./ipsec.sh $c $c 60 8 "" "--rx-descs $d" < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > $out
			[ -n "$RAW" ] && cat $out >> "$RAW"
			sent=$(grep -o "packets sent: [0-9]*" $out | grep -o "[0-9]*$")
			rate=$(grep -o "packets sent: [0-9]*, rate [0-9.]*" $out | grep -o "[0-9.]*$")
			ok=$(grep -o "Total: received [0-9]*, decrypted+authenticated [0-9]*" $out | grep -o "[0-9]*$")
			printf "%-10s %-6s %-6s %-12s %s\n" IPsec $c $d "$rate Mpps" "$(awk -v r=$rate -v d=$ok -v n=$sent 'BEGIN{printf "%.1f Mpps", r * d / n}')"
		done
		./cleartext.sh 4 4 60 8 "" "--rx-descs $d" < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > $out
		[ -n "$RAW" ] && cat $out >> "$RAW"
		sent=$(grep -o "Total: sent [0-9]*" $out | grep -o "[0-9]*$")
		rate=$(grep -o "Total: sent [0-9]*.*rate [0-9.]*" $out | grep -o "[0-9.]*$")
		ok=$(grep -o "Total: flows [0-9]*, received [0-9]*" $out | grep -o "[0-9]*$")
		printf "%-10s %-6s %-6s %-12s %s\n" cleartext 4 $d "$rate Mpps" "$(awk -v r=$rate -v d=$ok -v n=$sent 'BEGIN{printf "%.1f Mpps", r * d / n}')"
	done
done
rm -f $out
