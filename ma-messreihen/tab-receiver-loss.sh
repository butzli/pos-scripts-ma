#!/bin/bash
# Reproduces Table "tab:receiver-loss" (Section 5.3): packets lost in the receiver, by setup measure.
# pact -> stoi, 60-byte packets, 30 s, RUNS runs each (default 3), flow control and transparent huge pages off:
# IPsec with 8 SAs at 40 Mpps and cleartext with 4 flows at 20 Mpps, i.e. 5 Mpps per receive queue. The loss is the
# number of packets sent minus the number decrypted (IPsec) or received in sequence (cleartext).
#   [RUNS=n] tab-receiver-loss.sh "RINGS" ["GEN-ARGS"]   RINGS = sizes of the receive queues to measure, e.g. "512 4096";
#                                                        GEN-ARGS = extra options for the generators: "--ramp 0" = start
#                                                        at the full rate instead of the gradual start
# The script measures the state the nodes are in and prints it first. The rows of the table combine three measures:
#   reserved cores:   after ./setup/testbed-setup.sh setup (the standard setup); without them:
#                     pos nodes bootparameter -d NODE isolcpus nohz_full rcu_nocbs irqaffinity psi (transparent_hugepage
#                     stays), reset, setup/node-setup-cx7.sh on both nodes, afterwards ./setup/testbed-setup.sh setup
#   4,096 descriptors: RINGS 4096 (default of the sinks) instead of 512
#   gradual start:    without "--ramp 0" (default of the generators)
#   with reserved cores:    tab-receiver-loss.sh "512 4096"; tab-receiver-loss.sh "512 4096" "--ramp 0"
#   without reserved cores: tab-receiver-loss.sh "512 4096"
# Run on coinbase in ~/pos-scripts. RAW=file appends the output of all runs to file.
cd ~/pos-scripts
out=$(mktemp); st=$(mktemp)
printf '#!/bin/bash\necho "reserved CPUs: $(cat /sys/devices/system/cpu/isolated), huge pages: $(cat /sys/kernel/mm/transparent_hugepage/enabled)"\n' > $st
echo "stoi: $(./prun.sh stoi $st | tail -1)"; echo "pact: $(./prun.sh pact $st | tail -1)"
printf "%-34s %-6s %-12s %s\n" "Run $2" Ring Sent Lost
for d in ${1:-512 4096}; do
	for i in $(seq ${RUNS:-3}); do
		./ipsec.sh 8 8 60 30 "" "--rx-descs $d" "-r 40 $2" < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > $out
		[ -n "$RAW" ] && cat $out >> "$RAW"
		sent=$(grep -o "packets sent: [0-9]*" $out | grep -o "[0-9]*$")
		ok=$(grep -o "Total: received [0-9]*, decrypted+authenticated [0-9]*" $out | grep -o "[0-9]*$")
		printf "%-34s %-6s %-12s %s\n" "IPsec, 8 SAs, 40 Mpps, 30 s" $d "$sent" $((sent - ok))
		./cleartext.sh 4 4 60 30 "-r 20 $2" "--rx-descs $d" < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > $out
		[ -n "$RAW" ] && cat $out >> "$RAW"
		sent=$(grep -o "Total: sent [0-9]*" $out | grep -o "[0-9]*$")
		ok=$(grep -o "Total: flows [0-9]*, received [0-9]*" $out | grep -o "[0-9]*$")
		printf "%-34s %-6s %-12s %s\n" "cleartext, 4 flows, 20 Mpps, 30 s" $d "$sent" $((sent - ok))
	done
done
rm -f $out $st
