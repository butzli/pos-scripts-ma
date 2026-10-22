# pos-scripts-ma
Setup and measurement scripts for my master's thesis (starting 02/07/2026, fixed end date 04/01/2027): [MoonGen](https://github.com/butzli/MoonGen) as an IPsec traffic generator on the TUM I8 testbed.

They target the nodes `pact` and `stoi`. Copy the folder to `~/pos-scripts` on the management host and run everything from there; an allocation containing both nodes is required.

| Script | Purpose |
|---|---|
| `setup/testbed-setup.sh setup` | set boot parameters, reset both nodes, build MoonGen on them |
| `setup/node-setup-cx7.sh` | per-node part of the setup (called by the script above) |
| `setup/state.sh` | show a node's state: `./prun.sh pact setup/state.sh` |
| `prun.sh NODE FILE` | run a script file on a node and print its output |
| `ipsec.sh`, `cleartext.sh` | one run in one direction, `pact` → `stoi`, with and without ESP |
| `transceiver.sh` | one bidirectional run, one result line with the loss per node (`transceiver-node.sh` is its part that runs on the node) |
| `pmu-rotate.sh` | start-up rotation of the performance counters, used by `ipsec.sh` and `transceiver.sh`: briefly reprograms the performance counters of the reserved cores after the first packets, which lifts the IPsec generator to its upper send level; `PMU_ROTATE=0` in front of the call leaves it out |
| `ike/` | key exchange by IKEv2 (strongSwan) instead of the fixed test SAs, see below |
| `interop/` | tests against the IPsec implementation of the Linux kernel, see below |
| `ma-messreihen/` | measurement series behind the tables of the thesis |

The run scripts use fixed test SAs (SPI 1000 + i, one well-known key). Two switches change that, for `ipsec.sh`, `transceiver.sh` and the tests in `interop/` alike:

| Switch | Effect |
|---|---|
| `IKE=1` in front of the call | the SAs are negotiated by strongSwan before the run (`ike/ike-up.sh`), always with extended sequence numbers (ESN) |
| `--esn` as extra argument (`ESN=1` for `interop/`) | the fixed test SAs with ESN |

All four programs (`ipsec-gen`, `ipsec-sink`, `plain-gen`, `plain-sink`, and the two transceivers built from them) carry the same payload (magic, flow, sequence number) in the (inner) UDP packet, so each receiver also checks the traffic of the other kind of generator after a device in between has en- or decrypted it. `ipsec-sink` reports that check in its lines starting with `Payload:`, `transceiver.sh` as `pmiss` (payload sequence numbers missing end to end).

| Switch for `transceiver.sh` | Effect |
|---|---|
| `CLEARTEXT=pact`, `stoi` or `both` in front of the call | that node runs `plain-transceiver.lua` (cleartext UDP) instead of `ipsec-transceiver.lua`; `both` is a cleartext run between the nodes, a single node is the cleartext side of a device in between that en- and decrypts. In the result line, `ok` counts packets with the payload of `plain-gen`, `recv` also those without it (e.g. the decrypted traffic of `ipsec-gen`) |

| Script in `ike/` | Purpose |
|---|---|
| `ike-up.sh [TUNNELS]` | start strongSwan on both nodes, negotiate the tunnels, write the SAs to `/root/sas.txt` on both nodes (used with `--sa-file`), stop strongSwan; `KEEP=1` leaves it running for a peer that holds the SAs itself |
| `ike-down.sh` | stop strongSwan on both nodes |
| `ike-setup.sh`, `ike-sa-file.sh` | per-node parts: strongSwan configuration, export of the negotiated SAs |

| Script in `interop/` | Purpose |
|---|---|
| `kernel-rx.sh` | `ipsec-gen` on `pact` → the kernel of `stoi` decrypts (`kernel-rx-setup.sh`, `udp-count.py` run on `stoi`) |
| `kernel-tx.sh` | the kernel of `stoi` encrypts → `ipsec-sink` on `pact` (`kernel-tx-setup.sh`, `udp-send.py` run on `stoi`) |

| Script in `ma-messreihen/` | Table in the thesis | Section | Content |
|---|---|---|---|
| `tab-receiver-loss.sh` | Table 2, `tab:receiver-loss` | 5.3 | receiver loss with and without reserved cores, 4,096 descriptors and gradual start |
| `tab-rx-descs.sh` | none, figures in the text after Table 2 | 5.3 | rate taken at full load with 512 and with 4,096 descriptors per receive queue |
| `tab-rx-path.sh` | Table 3, `tab:rx-path` | 5.3 | decrypted rate by receive configuration |
| `tab-interop.sh` | Table 4, `tab:interop` | 6.1 | generator and receiver against the Linux kernel, derived SAs, ESN and IKE |
| `tab-cleartext-send-rate.sh` | Table 5, `tab:cleartext-send-rate` (Figure 8a) | 6.1 | cleartext generator: send rate by number of cores and share received |
| `tab-esp-send-rate.sh` | Table 6, `tab:esp-send-rate` (Figure 8) | 6.1 | ESP send rate by number of cores and packet size |
| `tab-loss-by-rate.sh` | Table 7, `tab:loss-by-rate` | 6.1 | runs without loss by rate; the one-direction rows, and single bidirectional rates |
| `tab-loss-by-rate-steps.sh` | Table 7 (both-directions rows), Figure 9, `fig:loss-steps` | 6.1 | bidirectional limit by stepping down: up to 10 runs per rate, confirmed one step below (calls `tab-loss-by-rate.sh`) |
| `tab-sa-queue-distribution.sh` | Table 8, `tab:sa-queue-distribution` | 6.1 | SAs assigned by RSS and by flow rules |
