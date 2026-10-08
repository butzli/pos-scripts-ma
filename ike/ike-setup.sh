#!/bin/bash
# usage (on the node): ROLE=pact|stoi [N=<tunnels>] ike-setup.sh
# strongSwan (apt-get install strongswan-swanctl charon-systemd) negotiates the SAs that were set by hand before.
# pact acts as N peers: peer i has the address 192.168.0.(1+i), its own IKE SA (IKEv2, test PSK) with stoi
# (192.168.1.1) and one child SA in tunnel mode with AES-256-GCM (16 byte ICV) and ESN for
# 10.0.0.(1+i) <-> 10.1.0.1; stoi accepts all of them with one connection.
# Establish them with "swanctl --initiate --child ma<i>" on pact; the negotiated SPIs and keys are then in
# "ip xfrm state" (ike-sa-file.sh).
IF=ens4f1np1
N=${N:-1}
SECRET=moongen-interop-test
if ! command -v swanctl > /dev/null; then
	DEBIAN_FRONTEND=noninteractive apt-get install -y strongswan-swanctl charon-systemd
	systemctl disable strongswan # only running between ike-up.sh and ike-down.sh
fi
systemctl restart strongswan # drops the SAs of an earlier run
sleep 1
ip xfrm state flush
ip xfrm policy flush
{
	echo "connections {"
	if [ "$ROLE" = pact ]; then
		ip route replace 192.168.1.0/24 dev $IF
		ip route replace 10.1.0.0/24 dev $IF
		for i in $(seq 0 $((N - 1))); do
			ip addr replace 192.168.0.$((1 + i))/24 dev $IF
			ip addr replace 10.0.0.$((1 + i))/32 dev lo
			cat <<E2
	ma$i {
		version = 2
		local_addrs = 192.168.0.$((1 + i))
		remote_addrs = 192.168.1.1
		proposals = aes256gcm16-prfsha384-ecp384
		rekey_time = 24h
		local {
			auth = psk
			id = 192.168.0.$((1 + i))
		}
		remote {
			auth = psk
			id = 192.168.1.1
		}
		children {
			ma$i {
				mode = tunnel
				local_ts = 10.0.0.$((1 + i))/32
				remote_ts = 10.1.0.1/32
				esp_proposals = aes256gcm16-esn
				rekey_time = 24h
				replay_window = 64
			}
		}
	}
E2
		done
	else
		ip addr replace 192.168.1.1/24 dev $IF
		ip addr replace 10.1.0.1/32 dev lo
		ip route replace 192.168.0.0/24 dev $IF
		ip route replace 10.0.0.0/24 dev $IF
		cat <<E2
	ma {
		version = 2
		local_addrs = 192.168.1.1
		remote_addrs = 192.168.0.0/24
		proposals = aes256gcm16-prfsha384-ecp384
		rekey_time = 24h
		local {
			auth = psk
			id = 192.168.1.1
		}
		remote {
			auth = psk
		}
		children {
			ma {
				mode = tunnel
				local_ts = 10.1.0.1/32
				remote_ts = 10.0.0.0/24
				esp_proposals = aes256gcm16-esn
				rekey_time = 24h
				replay_window = 64
			}
		}
	}
E2
	fi
	echo "}"
	echo "secrets { ike-ma { secret = \"$SECRET\" } }"
} > /etc/swanctl/conf.d/ma.conf
swanctl --load-all 2>&1 | grep -v plugin
