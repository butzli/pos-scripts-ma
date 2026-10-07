# pos-scripts-ma
Scripts for my master's thesis - starting 02/07/2026, fixed enddate 04/01/2027.

They run [MoonGen](https://github.com/butzli/MoonGen) as an IPsec traffic generator on the nodes `pact` and `stoi` of the TUM I8 testbed. Copy the folder to `~/pos-scripts` on the management host and run everything from there; an allocation containing both nodes is required.

| Script | Purpose |
|---|---|
| `setup/testbed-setup.sh setup` | set boot parameters, reset both nodes, build MoonGen on them |
| `setup/node-setup-cx7.sh` | per-node part of the setup (called by the script above) |
| `setup/state.sh` | show a node's state: `./prun.sh pact setup/state.sh` |
| `prun.sh NODE FILE` | run a script file on a node and print its output |
| `ipsec.sh`, `cleartext.sh` | one run `pact` → `stoi`, with and without ESP |
| `trxq.sh` | one bidirectional run, one result line with the loss per node (`trxnode-body.sh` is its part that runs on the node) |
| `ma-messreihen/` | measurement series behind the tables of the thesis |
