#!/bin/bash
# Highest rate without loss in both directions, found by stepping down: ipsec-transceiver on both nodes, TXCORES / RXCORES
# per node, RATE per direction, runs of SECS (default 30). Starting at START Mpps, up to N runs (default 10) per rate;
# the first run with loss moves on to the next lower rate (STEP Mpps lower, default 1). A rate with N runs without loss
# is the candidate, and the next lower rate is run N times as well to confirm it; if that one loses packets, the search
# goes on downwards from there. One line per run and one result line, both also appended to LOG (default
# ~/diag/steps-TXCORES.log); RAW=file appends the output of all runs to file.
#   tab-loss-by-rate-steps.sh 8 8 68;  tab-loss-by-rate-steps.sh 12 12 86;  tab-loss-by-rate-steps.sh 15 15 85
# Run on coinbase in ~/pos-scripts after ./setup/testbed-setup.sh setup.
cd ~/pos-scripts
T=$1; R=$2; r=$3; N=${4:-10}; STEP=${5:-1}; D=${6:-30}; LOG=${LOG:-~/diag/steps-$T.log}
log() { echo "$*" | tee -a $LOG; }
log "== $(date +%T) bidi $T/$R from $r Mpps, $N runs per rate"
cand=
while [ "$r" -gt 0 ]; do
	ok=0
	for i in $(seq $N); do
		o=$(bash ma-messreihen/tab-loss-by-rate.sh bidi $T $R $r $D | tail -1)
		lp=$(echo "$o" | grep -oP 'lost on pact \K-?[0-9]+'); ls=$(echo "$o" | grep -oP 'lost on stoi \K-?[0-9]+')
		w=$(echo "$o" | grep -oP 'rate warnings \K[0-9]+ / [0-9]+')
		if [ -z "$lp" ] || [ -z "$ls" ] || ! echo "$o" | grep -qP 'sent [0-9]+ / [0-9]+'; then
			log "$(date +%T) $r Mpps run $i: NO RESULT, stopping: $o"; exit 1
		fi
		log "$(date +%T) $r Mpps run $i: lost on pact $lp, lost on stoi $ls, rate warnings $w"
		[ "$lp" = 0 ] && [ "$ls" = 0 ] && [ "$w" = "0 / 0" ] || break
		ok=$i
	done
	if [ "$ok" = "$N" ]; then
		if [ -n "$cand" ]; then
			log "== $(date +%T) RESULT bidi $T/$R: $cand Mpps without loss in $N of $N runs, confirmed at $r Mpps"; exit 0
		fi
		cand=$r
	else
		cand=
	fi
	r=$((r - STEP))
done
