#!/bin/bash
# usage: [KEEP=1] ike-up.sh [TUNNELS]   starts strongSwan on pact and stoi, negotiates TUNNELS tunnels between them
# (IKEv2, see ike-setup.sh), writes the SAs of both directions to /root/sas.txt on both nodes and stops strongSwan
# again. Every MoonGen script then uses them with "--sa-file /root/sas.txt" instead of the fixed test SAs, e.g.
#   ./ipsec.sh 8 8 60 30 "--sa-file /root/sas.txt"            (ipsec-gen on pact -> ipsec-sink on stoi)
#   ./trxq.sh 8 8 40 30 60 --sa-file /root/sas.txt            (ipsec-transceiver on both nodes)
# KEEP=1 leaves strongSwan running: needed when the peer of the MoonGen script holds the SAs itself (kernel, DUT),
# because stopping strongSwan deletes them there; stop it with ike-down.sh after the run. Such a peer also needs
# new SAs for every run: the senders start with sequence number 1 again, which it rejects as replay.
cd ~/pos-scripts/ike
N=${1:-1}
ssh stoi "ROLE=stoi N=$N bash -s" < ike-setup.sh > /dev/null 2>&1
ssh pact "ROLE=pact N=$N bash -s" < ike-setup.sh > /dev/null 2>&1
ssh pact "for i in \$(seq 0 $((N - 1))); do swanctl --initiate --child ma\$i 2>&1 | grep -E 'CHILD_SA.*established|fail|error' | grep -v plugin; done"
for node in pact stoi; do
	ssh $node "ROLE=$node bash -s > /root/sas.txt; echo $node: \$(grep -c ^out /root/sas.txt) SAs out, \$(grep -c ^in /root/sas.txt) SAs in" < ike-sa-file.sh
done
[ -n "$KEEP" ] || bash ike-down.sh
