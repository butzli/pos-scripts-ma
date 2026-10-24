#!/bin/bash
# Loss of the measurement chain by size of the inner packet (Figure "fig:size-sweep"): N bidi runs of 60 s with T
# transmit and T receive cores per node at R Mpps in each direction per inner packet size, from 60 bytes in steps of 4,
# otherwise as in tab-loss-by-rate.sh. Stops after three sizes in a row in which every run lost at least 1 % on the
# worse node, or at 192 bytes (where 95 Mpps fill the 200 Gbit/s link).
#   fig-size-sweep.sh [R] [T] [N]       default: 95 Mpps, 15/15 cores, 3 runs per size
# One line per run in LOG (default ~/diag/size-sweep.log) with the loss on each node as a share of the packets the
# other node sent; RAW=file appends the output of all runs to file.
# Run on coinbase in ~/pos-scripts after ./setup/testbed-setup.sh setup.
cd ~/pos-scripts
R=${1:-95}; T=${2:-15}; N=${3:-3}; L=${LOG:-~/diag/size-sweep.log}; bad=0
echo "== $(date '+%F %T') start $T/$T at $R Mpps, $N runs per size, sizes from 60 in steps of 4" >> $L
for s in $(seq 60 4 192); do
	allbad=1
	for k in $(seq $N); do
		o=$(SIZE=$s RAW=$RAW bash ma-messreihen/tab-loss-by-rate.sh bidi $T $T $R 60 2>&1 | tail -1)
		sp=$(echo "$o" | grep -oP 'sent \K[0-9]+'); ss=$(echo "$o" | grep -oP 'sent [0-9]+ / \K[0-9]+')
		lp=$(echo "$o" | grep -oP 'lost on pact \K-?[0-9]+'); ls=$(echo "$o" | grep -oP 'lost on stoi \K-?[0-9]+')
		if [ -z "$sp" ] || [ -z "$ss" ] || [ -z "$lp" ] || [ -z "$ls" ]; then echo "== $(date '+%F %T') size $s run $k: no result, stopping: $o" >> $L; exit 1; fi
		# packets lost on pact were sent by stoi and vice versa
		w=$(awk -v lp=$lp -v ls=$ls -v sp=$sp -v ss=$ss 'BEGIN { a = 100 * lp / ss; b = 100 * ls / sp; m = a > b ? a : b; printf "%.6f %.6f %.6f", a, b, m }')
		set -- $w
		echo "$(date '+%F %T') size $s run $k: $o | loss pact $1 %, stoi $2 %, worse $3 %" >> $L
		awk -v m=$3 'BEGIN { exit !(m < 1) }' && allbad=0
	done
	[ $allbad = 1 ] && bad=$((bad + 1)) || bad=0
	[ $bad -ge 3 ] && { echo "== $(date '+%F %T') stopped: three sizes in a row with at least 1 % loss in every run" >> $L; exit 0; }
done
echo "== $(date '+%F %T') stopped at the largest size" >> $L
