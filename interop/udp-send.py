#!/usr/bin/env python3
# usage: udp-send.py COUNT [PAYLOAD] [SAS] [PPS] [ike]  -- sends COUNT UDP datagrams per SA from 10.1.0.(1+i):1234
# to 10.0.0.1:5678 at PPS datagrams per second and SA; the kernel encrypts them (see kernel-tx-setup.sh)
# with "ike" from 10.1.0.1:1234 to 10.0.0.(1+i):5678 instead, the addresses of the SAs of ike-setup.sh
import socket
import sys
import time

count = int(sys.argv[1])
payload = bytes(int(sys.argv[2]) if len(sys.argv) > 2 else 18)
sas = int(sys.argv[3]) if len(sys.argv) > 3 else 1
pps = float(sys.argv[4]) if len(sys.argv) > 4 else 10000
ike = len(sys.argv) > 5 and sys.argv[5] == "ike"
socks = []
for i in range(sas):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("10.1.0.%d" % (1 if ike else 1 + i), 1234))
    s.connect(("10.0.0.%d" % (1 + i if ike else 1), 5678))
    socks.append(s)
sent, errors = [0] * sas, 0
start = time.time()
for n in range(count):
    for i, s in enumerate(socks):
        try:
            s.send(payload)
            sent[i] += 1
        except OSError:
            errors += 1
    delay = start + (n + 1) / pps - time.time()
    if delay > 0:
        time.sleep(delay)
for i in range(sas):
    print("%s -> %s: %d datagrams sent" % (socks[i].getsockname()[0], socks[i].getpeername()[0], sent[i]))
print("UDP datagrams sent: %d, send errors: %d, %.1f s" % (sum(sent), errors, time.time() - start))
