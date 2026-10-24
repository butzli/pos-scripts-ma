#!/bin/bash
# Operating point of the measurement chain in both directions (Table "tab:loss-by-rate", Figure "fig:loss-steps"),
# searched by load classification after MLRsearch (RFC 9971) with three search goals on the same trials of SECS
# (default 60 s, the Goal Final Trial Duration of all goals):
#   goal     loss ratio  duration sum  exceed ratio
#   RFC2544  0           60 s          0     example goal 1 of RFC 9971, Appendix C.1 (RFC 2544 compliant)
#   NDR      0           120 s         0.5   example goal 2 of RFC 9971, Appendix C.1 (ETSI TST009)
#   PDR      1e-6        600 s         0.2   operating point: at most 20 % of at least ten trials above 1e-6
# Transceivers on both nodes, TXCORES / RXCORES per node, RATE per direction. A trial meets a goal (low loss) if the
# senders reach the requested rate without a warning, the packets lost are accounted for by the counters of the
# receiving node or the link (unaccounted at most 1 % of the loss plus one packet: the counters are read a moment
# apart), and the loss ratio of the worse direction is at most the goal's loss ratio. Trials are repeated at a rate
# until every goal still open is classified there (RFC 9971, Appendix A, all trials full-length): Lower Bound or
# Upper Bound. Starting at START Mpps, the rate goes down by STEP (default 1) until each goal has its first Lower
# Bound, its Relevant Lower Bound (the lowest Upper Bound above it is its Relevant Upper Bound).
# One line per trial and the result, both also appended to LOG (default ~/diag/steps-TXCORES.log);
# RAW=file appends the output of all trials to file. ARGS go to the transceivers of both nodes.
#   tab-loss-by-rate-steps.sh 12 12 92;  CLEARTEXT=both tab-loss-by-rate-steps.sh 12 12 96
# Run on coinbase in ~/pos-scripts after ./setup/testbed-setup.sh setup.
cd ~/pos-scripts
T=$1; R=$2; r=$3; STEP=${STEP:-1}; D=${SECS:-60}; X="${*:4}"; LOG=${LOG:-~/diag/steps-$T.log}
NAME=(RFC2544 NDR PDR); GLR=(0 0 1e-6); GDS=(60 120 600); GER=(0 0.5 0.2)
log() { echo "$*" | tee -a $LOG; }
# RFC 9971, Appendix A, with full-length trials only: low and high = seconds of low- and high-loss trials
classify() {
	awk -v lo=$1 -v hi=$2 -v gds=$3 -v ger=$4 'BEGIN {
		whole = lo + hi; if (whole < gds) whole = gds; q = whole * ger
		pess = (whole - lo <= q); opt = (hi <= q)
		print ((pess && opt) ? "lower" : (!pess && !opt) ? "upper" : "undecided") }'
}
goals=; for g in 0 1 2; do goals="$goals, ${NAME[$g]} (loss ratio ${GLR[$g]}, duration sum ${GDS[$g]} s, exceed ratio ${GER[$g]})"; done
log "== $(date +%T) bidi $T/$R ${CLEARTEXT:+cleartext=$CLEARTEXT }$X from $r Mpps, trials of $D s$goals"
# GOALS="2" (indices into NAME) searches only these goals, e.g. the PDR above a search that started too low
res=(- - -); up=("" "" ""); for g in ${GOALS:-0 1 2}; do res[$g]=; done
open() { [ -z "${res[0]}" ] || [ -z "${res[1]}" ] || [ -z "${res[2]}" ]; }
while [ "$r" -gt 0 ] && open; do
	lo=(0 0 0); hi=(0 0 0); c=(done done done); i=0
	while :; do
		und=0
		for g in 0 1 2; do
			[ -z "${res[$g]}" ] && c[$g]=$(classify ${lo[$g]} ${hi[$g]} ${GDS[$g]} ${GER[$g]})
			[ "${c[$g]}" = undecided ] && und=1
		done
		[ $und = 1 ] || break
		i=$((i + 1))
		o=$(bash ma-messreihen/tab-loss-by-rate.sh bidi $T $R $r $D "$X" | tail -1)
		lp=$(echo "$o" | grep -oP 'lost on pact \K-?[0-9]+'); ls=$(echo "$o" | grep -oP 'lost on stoi \K-?[0-9]+')
		sp=$(echo "$o" | grep -oP 'sent \K[0-9]+'); ss=$(echo "$o" | grep -oP 'sent [0-9]+ / \K[0-9]+')
		w=$(echo "$o" | grep -oP 'rate warnings \K[0-9]+ / [0-9]+'); u=$(echo "$o" | grep -oP 'unaccounted \K-?[0-9]+ / -?[0-9]+')
		if [ -z "$lp" ] || [ -z "$ls" ] || [ -z "$sp" ] || [ -z "$ss" ] || [ -z "$u" ]; then
			log "$(date +%T) $r Mpps trial $i: NO RESULT, stopping: $o"; exit 1
		fi
		# loss ratio of the worse direction: lost on pact was sent by stoi and vice versa
		lr=$(awk -v lp=$lp -v ls=$ls -v sp=$sp -v ss=$ss 'BEGIN { a = lp / ss; b = ls / sp; printf "%.3g", (a > b ? a : b) }')
		valid=$(echo "$u $lp $ls" | awk '{ ok = ($1 < 0 ? -$1 : $1) <= 1 + 0.01 * $4 && ($3 < 0 ? -$3 : $3) <= 1 + 0.01 * $5; print (ok ? 1 : 0) }')
		[ "$w" = "0 / 0" ] || valid=0
		k=
		for g in 0 1 2; do
			v=$(awk -v lr=$lr -v ok=$valid -v gl=${GLR[$g]} 'BEGIN { print ((ok && lr <= gl) ? "low" : "high") }')
			[ $v = low ] && lo[$g]=$((lo[$g] + D)) || hi[$g]=$((hi[$g] + D)); k="$k, ${NAME[$g]} $v"
		done
		log "$(date +%T) $r Mpps trial $i: lost on pact $lp, lost on stoi $ls, loss ratio $lr, rate warnings $w, unaccounted $u$k"
	done
	for g in 0 1 2; do
		[ -z "${res[$g]}" ] || continue
		log "$(date +%T) $r Mpps: ${NAME[$g]} ${c[$g]} bound (${lo[$g]} s low loss, ${hi[$g]} s high loss)"
		[ "${c[$g]}" = lower ] && res[$g]=$r || up[$g]=$r
	done
	r=$((r - STEP))
done
for g in 0 1 2; do [ "${res[$g]}" = - ] && res[$g]="not searched"; done
log "== $(date +%T) RESULT bidi $T/$R: PDR ${res[2]:-none} Mpps (upper bound ${up[2]:-not measured}), NDR ${res[1]:-none} Mpps (upper bound ${up[1]:-not measured}), RFC2544 ${res[0]:-none} Mpps (upper bound ${up[0]:-not measured})"
