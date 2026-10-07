#!/bin/bash
# usage: prun.sh NODE SCRIPTFILE  -- run script on node, fetch output via "pos commands show" (await is flaky)
t=$(mktemp ~/pos-scripts/.prun.XXXXXX); { cat "$2"; echo; echo "echo PRUN-DONE"; } > "$t"; chmod 644 "$t"
id=$(pos commands launch "$1" --non-blocking --infile "$t" | tail -1)
for i in $(seq 150); do
  o=$(pos commands show "$id" 2>&1)
  echo "$o" | grep -q "^PRUN-DONE" && break
  sleep 2
done
rm -f "$t"
echo "$o" | grep -v "^PRUN-DONE"
