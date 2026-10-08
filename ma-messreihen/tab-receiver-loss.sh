#!/bin/bash
# Reproduces Table "tab:receiver-loss": packets lost in the receiver, by setup measure.
# pact -> stoi, 60-byte packets, 30 s, two runs each, flow control off: IPsec with 8 SAs at 40 Mpps and cleartext
# with 4 flows at 20 Mpps, i.e. 5 Mpps per receive queue. The loss is the number of packets sent minus the number
# decrypted (IPsec) or received in sequence (cleartext).
#   tab-receiver-loss.sh "RINGS" ["GEN-ARGS"]     RINGS = sizes of the receive queues to measure, e.g. "512 4096";
#                                                 GEN-ARGS = extra options for the generators, e.g. "--ramp 0"
# The script measures the state the nodes are in and prints it first. The columns of the table are:
#   without any measure:   no reserved cores, ring 512, transparent huge pages on
#   reserved cores:        after ./setup/testbed-setup.sh setup, ring 512, huge pages on
#   + larger queues:       the same with ring 4096
#   + huge pages off:      the same with huge pages off (the state after the setup)
# Without reserved cores: pos nodes bootparameter -d NODE isolcpus nohz_full rcu_nocbs irqaffinity psi, reset, run
# setup/node-setup-cx7.sh on both nodes. Huge pages on: echo always > /sys/kernel/mm/transparent_hugepage/enabled
# on both nodes. Run on coinbase in ~/pos-scripts. RAW=file appends the output of all runs to file.
cd ~/pos-scripts
out=$(mktemp); st=$(mktemp)
printf '#!/bin/bash\necho "reserved CPUs: $(cat /sys/devices/system/cpu/isolated), huge pages: $(cat /sys/kernel/mm/transparent_hugepage/enabled)"\n' > $st
echo "stoi: $(./prun.sh stoi $st | tail -1)"; echo "pact: $(./prun.sh pact $st | tail -1)"
printf "%-34s %-6s %-12s %s\n" "Run $2" Ring Sent Lost
for d in ${1:-512 4096}; do
	for i in 1 2; do
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
