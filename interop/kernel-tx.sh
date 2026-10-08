#!/bin/bash
# usage: [IKE=1|ESN=1] kernel-tx.sh SAS [PAYLOAD] [COUNT] [KERNEL-KEY]   Linux kernel on stoi encrypts -> ipsec-sink on pact port 1
# COUNT datagrams per SA at 10000 per second and SA; KERNEL-KEY (hex key + salt) only to test with a wrong key
# The SAs are the fixed test SAs, set in the kernel by hand (kernel-tx-setup.sh; ESN=1: with extended sequence
# numbers), or with IKE=1 the ones negotiated by strongSwan (../ike/ike-up.sh, always with ESN)
cd ~/pos-scripts/interop
N=${1:-1}; P=${2:-18}; C=${3:-50000}; K=$4
ssh stoi "pkill python3"
if [ -n "$IKE" ]; then
	KEEP=1 bash ../ike/ike-up.sh $N
	SA="--sa-file /root/sas.txt"; SEL="list src 192.168.1.1"
else
	ssh stoi "N=$N ESN=$ESN ${K:+KEY=$K} bash -s" < kernel-tx-setup.sh > /dev/null
	SA="--sas $N --tunnel-src 192.168.1.1 --tunnel-dst 192.168.0.1 ${ESN:+--esn}"; SEL=
fi
ssh stoi "cat > /root/udp-send.py" < udp-send.py
ssh pact "cd /root/MoonGen; nohup ./build/MoonGen examples/ipsec/ipsec-sink.lua 1 -c $N $SA -t $((C / 10000 + 22)) > /root/sink.log 2>&1 < /dev/null &"
sleep 14
ssh pact "pgrep MoonGen > /dev/null" || echo "ipsec-sink is not running"
echo "== stoi (kernel, $N SAs${IKE:+ negotiated by IKE}, UDP payload $P B, $C datagrams per SA)"
ssh stoi "python3 /root/udp-send.py $C $P $N 10000 ${IKE:+ike}; ip -s xfrm state $SEL | grep -E '^src|oseq|\(packets\)' | grep -v limit"
echo "== pact (ipsec-sink, $N queues)"
ssh pact "while pgrep MoonGen > /dev/null; do sleep 1; done; grep -E 'INFO.*(Queue|Total|NIC)|FATAL|ERROR|WARN|rror' /root/sink.log | cut -c1-230"
[ -z "$IKE" ] || bash ../ike/ike-down.sh
