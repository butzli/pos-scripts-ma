#!/bin/bash
# Loss of the measurement chain by offered rate (Section 6.1, operating point of the IPsec transceiver): IPsec, tunnel
# mode, AES-256-GCM, 60-byte inner packets, flow control and transparent huge pages off (standard setup).
# The run scripts rotate the performance counters of the transmit cores at the start (pmu-rotate.sh), as in the thesis.
#   trial-loss-by-rate.sh uni  TXCORES RXCORES "RATES" [SECS] ["GEN-ARGS"] ["SINK-ARGS"]   ipsec-gen on pact -> ipsec-sink on stoi
#   trial-loss-by-rate.sh bidi TXCORES RXCORES "RATES" [SECS] ["ARGS"]       ipsec-transceiver on both nodes, RATE per direction
# RATES in Mpps, e.g. "40 60 80"; SIZE=bytes in front of a bidi call sets the inner packet size (default 60). The loss is the number of packets sent minus the number decrypted by the peer,
# so it includes packets dropped in the receive buffer of the NIC, which the DPDK counter imissed does not show.
# The search for the highest rate without loss (Table "tab:loss-by-rate", Figure "fig:loss-steps") calls this script
# once per run (tab-loss-by-rate.sh). Direct comparison of twelve and 15 cores, alternating:
#   for r in 92 94 92 94; do trial-loss-by-rate.sh bidi 12 12 $r; trial-loss-by-rate.sh bidi 15 15 $r; done
# Run on coinbase in ~/pos-scripts after ./setup/testbed-setup.sh setup. RAW=file appends the output of all runs to file.
cd ~/pos-scripts
MODE=$1; T=$2; R=$3; RATES=$4; D=${5:-60}; XG=$6; XS=$7
f() { echo "$1" | grep -oP "$2" | head -1; }
for r in $RATES; do
	if [ "$MODE" = uni ]; then
		o=$(./ipsec.sh $T $R 60 $D "" "$XS" "-r $r $XG" < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
		[ -n "$RAW" ] && echo "$o" >> $RAW
		sent=$(f "$o" 'packets sent: \K[0-9]+'); ok=$(f "$o" 'Total: received [0-9]+, decrypted\+authenticated \K[0-9]+')
		echo "uni $T/$R ${D}s $XG $XS requested $r Mpps: achieved $(f "$o" 'packets sent: [0-9]+, rate \K[0-9.]+') Mpps, sent $sent, decrypted $ok, lost $((sent - ok)), rate warnings $(echo "$o" | grep -c 'reached only')"
	else
		o=$(OUT=${RAW:-/dev/null} ./transceiver.sh $T $R $r $D ${SIZE:-60} $XG | head -1)
		p=${o#*| pact }; p=${p%%|*}; s=${o##*| stoi }
		ps=$(f "$p" 'sent=\K[0-9]+'); pr=$(f "$p" 'ok=\K[0-9]+'); ss=$(f "$s" 'sent=\K[0-9]+'); sr=$(f "$s" 'ok=\K[0-9]+')
		# unaccounted: lost on a node minus what its own counters explain (full receive queue, discard in the
		# receive buffer of the NIC) minus what the link lost (transmitted by the peer's port, not received by its own)
		ua() { echo $(( $1 - ${2:-0} - ${3:-0} - ($4 - $5) )); }
		up=$(ua $((ss - pr)) "$(f "$p" 'drop=\K[0-9]+')" "$(f "$p" 'rx_prio0_buf_discard=\K[0-9]+')" "$(f "$s" 'txphy=\K[0-9]+')" "$(f "$p" 'rxphy=\K[0-9]+')")
		us=$(ua $((ps - sr)) "$(f "$s" 'drop=\K[0-9]+')" "$(f "$s" 'rx_prio0_buf_discard=\K[0-9]+')" "$(f "$p" 'txphy=\K[0-9]+')" "$(f "$s" 'rxphy=\K[0-9]+')")
		echo "bidi $T/$R ${D}s ${SIZE:-60}B $XG requested $r Mpps: achieved $(f "$p" 'rate=\K[0-9.]+') / $(f "$s" 'rate=\K[0-9.]+') Mpps, sent $ps / $ss, lost on pact $((ss - pr)), lost on stoi $((ps - sr)), rate warnings $(f "$p" 'warn=\K[0-9]+') / $(f "$s" 'warn=\K[0-9]+'), unaccounted $up / $us"
	fi
done
