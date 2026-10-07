#!/bin/bash
# Reproduces Table "tab:functional-tests" (Appendix A.3): functional tests with MoonGen scripts,
# flow control enabled, 60-byte packets.
# examples/l3-load-latency.lua on pact (send on port 1, receive on port 0) while stoi forwards between its
# ports with libmoon/examples/l2-forward.lua; the latency part aborts on the ConnectX.
# Run on coinbase in ~/pos-scripts after ./setup/testbed-setup.sh setup.
cd ~/pos-scripts
printf "%-18s %-6s %-7s %-12s %-12s %s\n" Script Cores Queues Sent Received Missing
ssh stoi "cd /root/MoonGen && timeout -s INT 50 ./build/MoonGen libmoon/examples/l2-forward.lua 1 0 > /root/fwd.log 2>&1" 2>/dev/null &
sleep 15
ssh pact "cd /root/MoonGen && timeout -s INT 25 ./build/MoonGen examples/l3-load-latency.lua 1 0 > /root/l3.log 2>&1" 2>/dev/null
sent=$(ssh pact 'grep -o "Device: id=1\] TX.*total [0-9]*" /root/l3.log | tail -1' 2>/dev/null | grep -o "[0-9]*$")
recv=$(ssh pact 'grep -o "Device: id=0\] RX.*total [0-9]*" /root/l3.log | tail -1' 2>/dev/null | grep -o "[0-9]*$")
printf "%-18s %-6s %-7s %-12s %-12s %s\n" l3-load-latency 1 1 "$sent" "$recv" $((sent - recv))
wait
