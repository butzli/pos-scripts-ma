#!/bin/bash
# usage: [IKE=1] [PMU_ROTATE=0] transceiver.sh TXCORES RXCORES RATE-MPPS [SECS] [SIZE] [EXTRA-ARGS-BOTH]
# One bidirectional ipsec-transceiver run pact port 1 <-> stoi port 1; appends one result line to ~/diag/fcoff.csv
# CLEARTEXT=pact|stoi|both: that node runs plain-transceiver (cleartext UDP) instead; both = a cleartext run between
# the nodes, one node = the cleartext side of a device in between that en- and decrypts (--sa-file stays on the ESP side)
cd ~/pos-scripts
T=$1; R=$2; RATE=$3; D=${4:-10}; S=${5:-60}; X="${*:6}"
OUT=${OUT:-~/diag/fcoff.csv}
# IKE=1: SAs negotiated by strongSwan (ike/ike-up.sh) instead of the fixed test SAs
[ -z "$IKE" ] || { bash ike/ike-up.sh $T; X="$X --sa-file /root/sas.txt"; }
mk() {
	local C=0; [ "$CLEARTEXT" = both -o "$CLEARTEXT" = $4 ] && C=1
	{ echo '#!/bin/bash'; echo "T=$T; R=$R; RATE=$RATE; D=$D; S=$S; LOCAL=$2; REMOTE=$3; X='$X'; CLEAR=$C; PMU_ROTATE=${PMU_ROTATE:-1}"; cat pmu-rotate.sh transceiver-node.sh; } > $1
}
mk transceiver-pact.sh 192.168.0.1 192.168.1.1 pact
mk transceiver-stoi.sh 192.168.1.1 192.168.0.1 stoi
# FIRST=stoi starts the transceiver on stoi before the one on pact (default: pact first)
if [ "$FIRST" = stoi ]; then
	b=$(pos commands launch stoi --non-blocking --infile transceiver-stoi.sh | tail -1)
	a=$(pos commands launch pact --non-blocking --infile transceiver-pact.sh | tail -1)
else
	a=$(pos commands launch pact --non-blocking --infile transceiver-pact.sh | tail -1)
	b=$(pos commands launch stoi --non-blocking --infile transceiver-stoi.sh | tail -1)
fi
get() {
	for i in $(seq 90); do o=$(pos commands show $1 2>&1); echo "$o" | grep -q TRX-DONE && break; sleep 2; done
	echo "$o" | grep -E '^(RES|DIAG)'
}
oa=$(get $a); ob=$(get $b)
pa=$(echo "$oa" | grep '^RES' | head -1); sb=$(echo "$ob" | grep '^RES' | head -1)
echo "$(date +%T) T=$T R=$R req=$RATE secs=$D size=$S $X ${CLEARTEXT:+cleartext=$CLEARTEXT }first=${FIRST:-pact} | pact ${pa#RES } | stoi ${sb#RES }" | tee -a $OUT
echo "$oa" | grep '^DIAG' | sed 's/^DIAG/   pact/'
echo "$ob" | grep '^DIAG' | sed 's/^DIAG/   stoi/'
