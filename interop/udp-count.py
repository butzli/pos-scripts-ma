#!/usr/bin/env python3
# usage: udp-count.py [SECONDS]  -- counts the UDP datagrams arriving on 10.1.0.1:5678 (the decrypted inner packets
# of ipsec-gen.lua) per source address and payload length; stops SECONDS after start or 3 s after the last datagram
import collections
import signal
import socket
import sys
import time

limit = float(sys.argv[1]) if len(sys.argv) > 1 else 60
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, 33, 64 << 20)  # 33 = SO_RCVBUFFORCE
s.bind(("10.1.0.1", 5678))
s.settimeout(0.5)
seen = collections.Counter()
end, last, stop = time.time() + limit, None, []
signal.signal(signal.SIGTERM, lambda *a: stop.append(1))  # kill = print the result now
while not stop and time.time() < end and (last is None or time.time() - last < 3):
    try:
        data, (src, port) = s.recvfrom(65535)
    except socket.timeout:
        continue
    seen[(src, port, len(data))] += 1
    last = time.time()
for (src, port, size), n in sorted(seen.items()):
    print("from %s:%d, UDP payload %d B: %d datagrams" % (src, port, size, n))
print("UDP datagrams received: %d" % sum(seen.values()))
