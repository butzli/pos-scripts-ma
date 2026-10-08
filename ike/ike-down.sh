#!/bin/bash
# usage: ike-down.sh   stops strongSwan on pact and stoi; this deletes the tunnels and their SAs in both kernels
for node in pact stoi; do
	ssh $node "systemctl stop strongswan"
done
