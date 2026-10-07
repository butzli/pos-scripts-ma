#!/bin/bash
# Run on the coinbase management node (needs node-setup-cx7.sh in the same directory).
#   ./setup/testbed-setup.sh setup                    set kernel boot parameters, reset pact+stoi, set up MoonGen on both
#   ./setup/testbed-setup.sh test [TX] [RX] [SECS]    send udp-load TX -> RX over ens4f1np1 (DPDK port 1)
# Requires an active calendar entry + allocation containing pact and stoi.

cd "$(dirname "$0")"

case "$1" in
setup)
	# Reserve 30 of the 32 cores of pact and stoi for MoonGen (CPUs 2-31 and their sibling threads 34-63):
	# no scheduler balancing, timer tick, RCU callbacks or interrupts there. Cores 0-1 stay with the
	# operating system. Without this, kernel work repeatedly interrupts a receive task and its RX queue overflows.
	# transparent_hugepage=never: otherwise the kernel thread khugepaged merges memory pages of the MoonGen process
	# into huge pages every 10 s and stalls all its tasks for 0.5-2 ms each time (TLB flushes on all cores, blocked
	# page faults); without flow control the RX queues overflow during such a stall.
	ISO=2-31,34-63
	for n in pact stoi; do
		pos nodes bootparameter $n isolcpus=$ISO nohz_full=$ISO rcu_nocbs=$ISO irqaffinity=0-1,32-33 psi=0 transparent_hugepage=never
	done
	r1=$(pos nodes reset pact --non-blocking | tail -1)
	r2=$(pos nodes reset stoi --non-blocking | tail -1)
	pos commands await "$r1" > /dev/null
	pos commands await "$r2" > /dev/null
	echo "reset done"
	s1=$(pos commands launch pact --infile node-setup-cx7.sh --non-blocking | tail -1)
	s2=$(pos commands launch stoi --infile node-setup-cx7.sh --non-blocking | tail -1)
	pos commands await "$s1" | tail -1 | sed 's/^/pact: /'
	pos commands await "$s2" | tail -1 | sed 's/^/stoi: /'
	;;
test)
	TX=${2:-pact}
	RX=${3:-stoi}
	SECS=${4:-10}
	PORT=1
	rx=$(pos commands launch "$RX" --non-blocking -- bash -c \
		"cd /root/MoonGen && timeout -s INT $((SECS + 30)) ./moongen-simple start udp-load::$PORT 2>&1 | grep -E 'total|ERROR'" | tail -1)
	sleep 15	# receiver DPDK init
	echo "== $TX (TX) =="
	pos commands launch -v "$TX" -- bash -c \
		"cd /root/MoonGen && timeout -s INT $((SECS + 30)) ./moongen-simple start udp-load:$PORT::timeLimit=${SECS}s 2>&1 | grep -E 'total|ERROR'"
	echo "== $RX (RX) =="
	pos commands await "$rx"
	;;
*)
	sed -n '2,5p' "$0"
	exit 1
	;;
esac
