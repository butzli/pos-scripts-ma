#!/bin/bash
# usage: cleartext.sh TXCORES RXCORES [SIZE] [SECS] [EXTRA-ARGS-GEN] [EXTRA-ARGS-SINK]   plain-gen on pact port 1 -> plain-sink on stoi port 1
cd ~/pos-scripts
T=${1:-4}; R=${2:-4}; S=${3:-60}; D=${4:-8}; XG=$5; XS=$6
cat > cleartext-sink.sh <<E2
#!/bin/bash
cd /root/MoonGen && ./build/MoonGen examples/ipsec/plain-sink.lua 1 -c $R -n $T -t $((D + 17)) $XS > /root/sink.log 2>&1
grep -E "INFO.*(Flow|Total|NIC)|FATAL|ERROR|WARN|rror" /root/sink.log | cut -c1-200
grep -E "^\[.*RX.*total" /root/sink.log | cut -c1-200
E2
cat > cleartext-gen.sh <<E2
#!/bin/bash
cd /root/MoonGen && ./build/MoonGen examples/ipsec/plain-gen.lua 1 -c $T -s $S -t $D $XG > /root/gen.log 2>&1
grep -E "INFO.*(Flow|Total)|FATAL|ERROR|WARN|rror" /root/gen.log | cut -c1-200
grep -E "^\[.*TX.*total" /root/gen.log | cut -c1-200
E2
r=$(pos commands launch stoi --non-blocking --infile cleartext-sink.sh | tail -1)
sleep 10
echo "== pact (gen, $T cores, $S B, $D s)"; ./prun.sh pact cleartext-gen.sh | grep -v -E "^20"
echo "== stoi (sink, $R queues)"
for i in $(seq 40); do o=$(pos commands show $r 2>&1); echo "$o" | grep -q -E "Total:|FATAL|rror" && break; sleep 3; done
echo "$o" | grep -v -E "^20"
