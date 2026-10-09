#!/bin/bash
# Reproduces Table "tab:interop" (Section 6.1): the generator and the receiver against the IPsec implementation of
# the Linux kernel on stoi, tunnel mode, AES-256-GCM, four SAs, 10000 packets per second and SA, 5 s per run.
#   generator -> kernel:  ipsec-gen on pact sends, the kernel of stoi decrypts       (interop/kernel-rx.sh)
#   kernel -> receiver:   the kernel of stoi encrypts, ipsec-sink on pact decrypts   (interop/kernel-tx.sh)
# Each direction with the derived SAs without and with ESN and with SAs negotiated by IKE (always with ESN), with
# 60 and 1400 byte inner packets, and once with a wrong key in the kernel, which must make the receiving end
# reject every packet.
# Accepted: UDP datagrams the kernel delivered, resp. packets ipsec-sink decrypted and authenticated;
# rejected: packets that failed the authentication there.
#   tab-interop.sh
# Run on coinbase in ~/pos-scripts after ./setup/testbed-setup.sh setup. RAW=file appends the output of all runs to file.
cd ~/pos-scripts
WRONG=00112233445566778899aabbccddeeff0123456789abcdef0123456789abcdeecafebabe # last byte of the AES key changed
f() { echo "$o" | grep -oP "$1" | awk '{ s += $1 } END { print s + 0 }'; }
# run DIRECTION SAS ESN SWITCH SIZE [KEY]; kernel-tx.sh takes the UDP payload (inner packet - 42) and a packet count
run() {
	if [ $1 = rx ]; then
		o=$(env $4 bash interop/kernel-rx.sh 4 $5 5 $6 2>&1)
		set -- "generator -> kernel" "$2" $3 $5 $(f 'packets sent: \K[0-9]+') $(f 'UDP datagrams received: \K[0-9]+') $(f 'failed \K[0-9]+')
	else
		o=$(env $4 bash interop/kernel-tx.sh 4 $(($5 - 42)) 50000 $6 2>&1)
		set -- "kernel -> receiver" "$2" $3 $5 $(f 'UDP datagrams sent: \K[0-9]+') $(f 'Total: received [0-9]+, decrypted\+authenticated \K[0-9]+') $(f 'Total: .*auth/ICV failures \K[0-9]+')
	fi
	[ -n "$RAW" ] && echo "$o" >> "$RAW"
	printf "%-20s %-10s %-4s %-7s %-8s %-9s %s\n" "$1" "$2" $3 "$4 B" $5 $6 $7
}
printf "%-20s %-10s %-4s %-7s %-8s %-9s %s\n" Direction SAs ESN Packet Sent Accepted Rejected
for d in rx tx; do
	for s in 60 1400; do
		run $d derived no X= $s
		run $d derived yes ESN=1 $s
		run $d IKE yes IKE=1 $s
	done
	run $d "wrong key" no X= 60 $WRONG
done
