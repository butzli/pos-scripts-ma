# Node-side function, copied into the run scripts by ipsec.sh and transceiver.sh (PMU_ROTATE=0 in front of the call leaves it out).
# On the reserved cores, the transmit cores of the IPsec generator often stay at a lower send level, on which they wait
# for their store buffer for about 60 % of their cycles. Briefly reprogramming the performance counters of the cores
# (perf stat with more events than counters, so that perf rotates them) ends this state for the rest of the run; why
# is not known. pmurotate LOG waits until the generator has sent its first packets (log line "inner frame") and does
# this once on all reserved cores. Start it in the background after the log file was removed.
pmurotate() {
	for i in $(seq 600); do grep -aq "inner frame" $1 2>/dev/null && break; sleep 0.1; done
	sleep 0.5
	perf stat -C $(cat /sys/devices/system/cpu/isolated) -e cycles,instructions,cache-misses,LLC-load-misses,LLC-store-misses,branch-misses -- sleep 0.1 > /dev/null 2>&1
}
