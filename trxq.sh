#!/bin/bash
# usage: trxq.sh TXCORES RXCORES RATE-MPPS [SECS] [SIZE] [EXTRA-ARGS-BOTH]
# One bidirectional ipsec-transceiver run pact port 1 <-> stoi port 1; appends one result line to ~/diag/fcoff.csv
cd ~/pos-scripts
T=$1; R=$2; RATE=$3; D=${4:-10}; S=${5:-60}; X="${*:6}"
OUT=${OUT:-~/diag/fcoff.csv}
mk() { { echo '#!/bin/bash'; echo "T=$T; R=$R; RATE=$RATE; D=$D; S=$S; LOCAL=$2; REMOTE=$3; X='$X'"; cat trxnode-body.sh; } > $1; }
mk trxq-pact.sh 192.168.0.1 192.168.1.1
mk trxq-stoi.sh 192.168.1.1 192.168.0.1
# FIRST=stoi starts the transceiver on stoi before the one on pact (default: pact first)
if [ "$FIRST" = stoi ]; then
	b=$(pos commands launch stoi --non-blocking --infile trxq-stoi.sh | tail -1)
	a=$(pos commands launch pact --non-blocking --infile trxq-pact.sh | tail -1)
else
	a=$(pos commands launch pact --non-blocking --infile trxq-pact.sh | tail -1)
	b=$(pos commands launch stoi --non-blocking --infile trxq-stoi.sh | tail -1)
fi
get() {
	for i in $(seq 90); do o=$(pos commands show $1 2>&1); echo "$o" | grep -q TRX-DONE && break; sleep 2; done
	echo "$o" | grep -E '^(RES|DIAG)'
}
oa=$(get $a); ob=$(get $b)
pa=$(echo "$oa" | grep '^RES' | head -1); sb=$(echo "$ob" | grep '^RES' | head -1)
echo "$(date +%T) T=$T R=$R req=$RATE secs=$D size=$S $X first=${FIRST:-pact} | pact ${pa#RES } | stoi ${sb#RES }" | tee -a $OUT
echo "$oa" | grep '^DIAG' | sed 's/^DIAG/   pact/'
echo "$ob" | grep '^DIAG' | sed 's/^DIAG/   stoi/'
