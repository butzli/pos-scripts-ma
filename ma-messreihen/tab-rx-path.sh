#!/bin/bash
# Reproduces Table "tab:rx-path" (Section 5.3): rate at which stoi decrypts, by receive configuration.
# ipsec-gen on pact without a rate limit -> ipsec-sink on stoi, 8, 16 and 30 SAs with one receive queue each,
# tunnel mode, AES-256-GCM, 60-byte inner packets, 8 s, flow control off. The sender offers more than the receiver
# can process; the decrypted rate is the send rate times the share of the packets sent that was decrypted.
#   tab-rx-path.sh LABEL ["SINK-ARGS"]
# The three columns of the table:
#   libmoon default:               libmoon/src/device.c with MTU 9000 and RTE_ETH_RX_OFFLOAD_SCATTER for mlx5
#                                  (the state before commit eaa4714 of the fork), MoonGen rebuilt, SINK-ARGS "--offloads"
#   MTU 1500, no scattered RX:     the fork as it is, SINK-ARGS "--offloads"
#   and receive offloads off:      the fork as it is, no SINK-ARGS (default of ipsec-sink)
# Run on coinbase in ~/pos-scripts after ./setup/testbed-setup.sh setup. RAW=file appends the output of all runs to file.
cd ~/pos-scripts
out=$(mktemp)
printf "%-34s %-5s %-12s %s\n" Configuration SAs "Send rate" "Decrypted"
for c in 8 16 30; do
	./ipsec.sh $c $c 60 8 "" "$2" < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > $out
	[ -n "$RAW" ] && cat $out >> "$RAW"
	sent=$(grep -o "packets sent: [0-9]*" $out | grep -o "[0-9]*$")
	rate=$(grep -o "packets sent: [0-9]*, rate [0-9.]*" $out | grep -o "[0-9.]*$")
	dec=$(grep -o "Total: received [0-9]*, decrypted+authenticated [0-9]*" $out | grep -o "[0-9]*$")
	printf "%-34s %-5s %-12s %s\n" "$1" $c "$rate Mpps" "$(awk -v r=$rate -v d=$dec -v n=$sent 'BEGIN{printf "%.1f Mpps", r * d / n}')"
done
rm -f $out
