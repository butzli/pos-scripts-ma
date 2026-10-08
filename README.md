# pos-scripts-ma
Setup and measurement scripts for my master's thesis (starting 02/07/2026, fixed end date 04/01/2027): [MoonGen](https://github.com/butzli/MoonGen) as an IPsec traffic generator on the TUM I8 testbed.

They target the nodes `pact` and `stoi`. Copy the folder to `~/pos-scripts` on the management host and run everything from there; an allocation containing both nodes is required.

| Script | Purpose |
|---|---|
| `setup/testbed-setup.sh setup` | set boot parameters, reset both nodes, build MoonGen on them |
| `setup/node-setup-cx7.sh` | per-node part of the setup (called by the script above) |
| `setup/state.sh` | show a node's state: `./prun.sh pact setup/state.sh` |
| `prun.sh NODE FILE` | run a script file on a node and print its output |
| `ipsec.sh`, `cleartext.sh` | one run `pact` → `stoi`, with and without ESP |
| `trxq.sh` | one bidirectional run, one result line with the loss per node (`trxnode-body.sh` is its part that runs on the node) |
| `ma-messreihen/` | measurement series behind the tables of the thesis |

| Script in `ma-messreihen/` | Table in the thesis | Section | Content |
|---|---|---|---|
| `tab-sender-scaling.sh` | Table 2, `tab:sender-scaling` | 6.3 | send rate by number of cores, no encryption |
| `tab-rx-path.sh` | Table 1, `tab:rx-path` | 5.3 | decrypted rate by receive configuration |
| `tab-receiver-loss.sh` | Table 3, `tab:receiver-loss` | 6.3 | receiver loss by setup measure |
| `tab-sa-queue-distribution.sh` | Table 4, `tab:sa-queue-distribution` | 6.3 | SAs assigned by RSS and by flow rules |
| `tab-rate-control.sh` | Table 5, `tab:rate-control` | 6.3 | requested and achieved send rate |
| `tab-esp-send-rate.sh` | not in the thesis yet | 6.3 | ESP send rate by number of cores and packet size |
| `tab-loss-by-rate.sh` | not in the thesis yet | 6.3 | loss by offered rate, one direction and bidirectional |
