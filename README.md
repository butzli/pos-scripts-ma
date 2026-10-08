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
| `trxq.sh` | one bidirectional run, one result line with the loss per node (`trxnode-body.sh` is its part that runs on the node) |
| `ike/` | key exchange by IKEv2 (strongSwan) instead of the fixed test SAs, see below |
| `interop/` | tests against the IPsec implementation of the Linux kernel, see below |
| `ma-messreihen/` | measurement series behind the tables of the thesis |

The run scripts use fixed test SAs (SPI 1000 + i, one well-known key). Two switches change that, for `ipsec.sh`, `trxq.sh` and the tests in `interop/` alike:

| Switch | Effect |
|---|---|
| `IKE=1` in front of the call | the SAs are negotiated by strongSwan before the run (`ike/ike-up.sh`), always with extended sequence numbers (ESN) |
| `--esn` as extra argument (`ESN=1` for `interop/`) | the fixed test SAs with ESN |

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
| `tab-receiver-loss.sh` | Table 1, `tab:receiver-loss` | 5.3 | receiver loss by setup measure |
| `tab-rx-path.sh` | Table 2, `tab:rx-path` | 5.3 | decrypted rate by receive configuration |
| `tab-sender-scaling.sh` | Table 3, `tab:sender-scaling` | 6.3 | send rate by number of cores, no encryption |
| `tab-esp-send-rate.sh` | Table 4, `tab:esp-send-rate` | 6.3 | ESP send rate by number of cores and packet size |
| `tab-loss-by-rate.sh` | Table 5, `tab:loss-by-rate` | 6.3 | highest rate without loss, one direction and bidirectional |
| `tab-sa-queue-distribution.sh` | Table 6, `tab:sa-queue-distribution` | 6.3 | SAs assigned by RSS and by flow rules |
