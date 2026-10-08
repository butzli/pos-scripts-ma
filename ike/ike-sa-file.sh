#!/bin/bash
# usage (on the node): ROLE=pact|stoi ike-sa-file.sh   prints the SAs negotiated by strongSwan (ike-setup.sh) as
# SA file for ipsec-gen.lua, ipsec-sink.lua and ipsec-transceiver.lua (--sa-file): direction (out = sent by this
# node), SPI, key + salt, outer source, outer destination, inner source, inner destination, "esn" if negotiated;
# sorted by direction and by the address of the peer on pact
[ "$ROLE" = pact ] && LOCAL=192.168.0. || LOCAL=192.168.1.
ip xfrm state | awk -v p=$LOCAL '
	/^src/ { src = $2; dst = $4; split(src, s, "."); split(dst, d, "."); esn = "" }
	/flag.* esn/ { esn = "esn" }
	/proto esp/ { spi = $4 }
	/aead/ { print (index(src, p) == 1 ? "out" : "in"), spi, $3, src, dst, "10." s[3] ".0." s[4], "10." d[3] ".0." d[4], esn }
' | sort -k1,1r -k4,4V -k5,5V
