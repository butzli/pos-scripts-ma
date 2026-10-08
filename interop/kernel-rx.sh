#!/bin/bash
# usage: [IKE=1|ESN=1] kernel-rx.sh SAS [SIZE] [SECS] [KERNEL-KEY]   ipsec-gen on pact port 1 -> Linux kernel on stoi decrypts
# 10000 packets per second and SA; KERNEL-KEY (hex key + salt) only to test with a wrong key
# The SAs are the fixed test SAs, set in the kernel by hand (kernel-rx-setup.sh; ESN=1: with extended sequence
# numbers), or with IKE=1 the ones negotiated by strongSwan (../ike/ike-up.sh, always with ESN)
cd ~/pos-scripts/interop
N=${1:-1}; S=${2:-60}; D=${3:-5}; K=$4
MAC=e8:9e:49:68:6b:79 # stoi ens4f1np1; the kernel does not accept unicast IP in a broadcast frame
ssh stoi "pkill python3"
if [ -n "$IKE" ]; then
	KEEP=1 bash ../ike/ike-up.sh $N
	SA="--sa-file /root/sas.txt"
else
	ssh stoi "N=$N ESN=$ESN ${K:+KEY=$K} bash -s" < kernel-rx-setup.sh > /dev/null
	SA="-c $N ${ESN:+--esn}"
fi
ssh stoi "cat > /root/udp-count.py" < udp-count.py
ssh stoi "cat /proc/net/xfrm_stat > /root/xfrm_stat.before; nohup python3 /root/udp-count.py $((D + 90)) > /root/udp.log 2>&1 < /dev/null &"
echo "== pact (ipsec-gen, $N cores/SAs${IKE:+ negotiated by IKE}, inner $S B, $D s)"
ssh pact "cd /root/MoonGen; ./build/MoonGen examples/ipsec/ipsec-gen.lua 1 $SA -s $S -t $D -r $(awk "BEGIN { print $N * 0.01 }") --dst-mac $MAC > /root/gen.log 2>&1
grep -E 'INFO.*(Core|Encryption)|FATAL|ERROR|WARN|rror' /root/gen.log | cut -c1-220"
echo "== stoi (kernel: UDP datagrams delivered, packets per SA, XFRM error counters that changed)"
ssh stoi "sleep 4; pkill python3; sleep 1; cat /root/udp.log
ip -s xfrm state list dst 192.168.1.1 | grep -E '^src|\(packets\)|failed' | grep -v limit
paste /root/xfrm_stat.before /proc/net/xfrm_stat | awk '\$2 != \$4 { print \$1, \$4 - \$2 }'"
[ -z "$IKE" ] || bash ../ike/ike-down.sh
