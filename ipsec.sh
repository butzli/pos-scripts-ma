#!/bin/bash
# usage: [IKE=1] ipsec.sh TXCORES RXCORES [SIZE] [SECS] [EXTRA-ARGS-BOTH] [EXTRA-ARGS-SINK] [EXTRA-ARGS-GEN]   ipsec-gen on pact port 1 -> ipsec-sink on stoi port 1
cd ~/pos-scripts
T=${1:-4}; R=${2:-4}; S=${3:-60}; D=${4:-8}; X=$5; XS=$6; XG=$7
# IKE=1: SAs negotiated by strongSwan (ike/ike-up.sh) instead of the fixed test SAs
[ -z "$IKE" ] || { bash ike/ike-up.sh $T; X="$X --sa-file /root/sas.txt"; }
cat > ipsec-sink.sh <<E2
#!/bin/bash
cd /root/MoonGen && ./build/MoonGen examples/ipsec/ipsec-sink.lua 1 -c $R --sas $T -t $((D + 17)) $X $XS > /root/sink.log 2>&1
grep -E "INFO.*(Queue|Total|NIC|Main)|FATAL|ERROR|WARN|rror" /root/sink.log | cut -c1-220
grep -E "total" /root/sink.log | cut -c1-220
echo SINK-DONE
E2
cat > ipsec-gen.sh <<E2
#!/bin/bash
cd /root/MoonGen && ./build/MoonGen examples/ipsec/ipsec-gen.lua 1 -c $T -s $S -t $D $X $XG > /root/gen.log 2>&1
grep -E "INFO.*(Core|Encryption)|FATAL|ERROR|WARN|rror" /root/gen.log | cut -c1-220
grep -E "total" /root/gen.log | cut -c1-220
E2
r=$(pos commands launch stoi --non-blocking --infile ipsec-sink.sh | tail -1)
sleep 11
echo "== pact (ipsec-gen, $T cores/SAs, inner $S B, $D s) $X"; ./prun.sh pact ipsec-gen.sh | grep -v -E "^20|^$"
echo "== stoi (ipsec-sink, $R queues)"
for i in $(seq 40); do o=$(pos commands show $r 2>&1); echo "$o" | grep -q -E "SINK-DONE" && break; sleep 3; done
echo "$o" | grep -v -E "^20|^$|SINK-DONE"
