#!/bin/bash
# usage (on stoi): N=<SAs> [KEY=<hex key + salt>] [ESN=1] kernel-rx-setup.sh
# Linux kernel (XFRM) as ESP receiver for ipsec-gen.lua: SA i has SPI 1000 + i, outer 192.168.0.(1+i) -> 192.168.1.1,
# inner 10.0.0.(1+i) -> 10.1.0.1, AES-GCM (RFC 4106) with 16 byte ICV, anti-replay window 64
IF=ens4f1np1
N=${N:-1}
KEY=${KEY:-00112233445566778899aabbccddeeff0123456789abcdef0123456789abcdefcafebabe}
ip addr replace 192.168.1.1/24 dev $IF
ip addr replace 10.1.0.1/32 dev lo
ip route replace 192.168.0.0/24 dev $IF
ip route replace 10.0.0.0/24 dev $IF
ip xfrm state flush
ip xfrm policy flush
for i in $(seq 0 $((N - 1))); do
	ip xfrm state add src 192.168.0.$((1 + i)) dst 192.168.1.1 proto esp spi $((1000 + i)) mode tunnel \
		replay-window 64 ${ESN:+flag esn} aead 'rfc4106(gcm(aes))' 0x$KEY 128
	ip xfrm policy add src 10.0.0.$((1 + i))/32 dst 10.1.0.1/32 dir in \
		tmpl src 192.168.0.$((1 + i)) dst 192.168.1.1 proto esp mode tunnel
done
ip xfrm state
ip xfrm policy
