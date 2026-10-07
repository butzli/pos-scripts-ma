#!/bin/bash
# MoonGen setup for a freshly reset ConnectX-7 node (pact/stoi, debian-trixie).
# Run once per reset, as root, via: pos commands launch NODE --infile node-setup-cx7.sh
set -e
cd /root

# mlx5 PMD needs libibverbs/libmlx5 at build time, otherwise DPDK silently builds without it
# ("Found 0 usable devices"). libipsec-mb-dev makes DPDK build the software AES-GCM crypto driver
# used by the IPsec scripts. ethtool is not part of the image.
apt-get update -q
apt-get install -y -q libibverbs-dev libipsec-mb-dev ethtool

git clone -q --recursive --branch v25.11 https://github.com/butzli/MoonGen.git
cd MoonGen

# moongen-simple refuses rx-only flows ("No valid flows remaining"); allow them so the
# receiving node can count a flow. No-op once the fix is in the fork.
sed -i 's/if #loadThread.flows == 0 then--and #countThread.flows == 0 then/if #loadThread.flows == 0 and #countThread.flows == 0 then/' interface/init.lua

# --noBind: ConnectX (mlx5, bifurcated) needs no vfio binding. The binding step would also
# bind the Intel DSA accelerator (0000:f2:01.0, drv=idxd) to vfio-pci, which hangs in the
# kernel (D state) and makes the node unusable until reset.
./build.sh --noBind > /root/build.log 2>&1

./setup-hugetlbfs.sh

# DPDK config, found by MoonGen when started in this directory: the crypto device for the IPsec
# scripts and, if the kernel was booted with isolated CPUs (see testbed-setup.sh), the cores to use:
# the main task stays on CPU 0, worker tasks only get isolated cores (first hardware thread of each).
cores=
for r in $(tr , ' ' < /sys/devices/system/cpu/isolated); do
	for n in $(seq ${r%-*} ${r#*-}); do
		[ "$(tr , - < /sys/devices/system/cpu/cpu$n/topology/thread_siblings_list | cut -d- -f1)" = "$n" ] && cores="$cores, $n"
	done
done
{
	echo 'DPDKConfig {'
	[ -n "$cores" ] && echo "	cores = {0$cores},"
	echo '	cli = { "--vdev=crypto_aesni_gcm0" },'
	echo '}'
} > dpdk-conf.lua

# Run all cores at full clock rate from the start: with the default governor (schedutil) a core
# first has to ramp up from 800 MHz when a task starts on it.
for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > $f; done

# Ethernet flow control off on all ConnectX ports (the driver default is on): with it, a receiver that is too slow
# throttles the sender with PAUSE frames, so the send rate depends on the receiver and short stalls of the receiver
# stay hidden. Without it, losses have to be read from the packets sent and received or from the hardware counters
# of the NIC (ethtool -S), not from the DPDK counter imissed alone.
for i in /sys/class/net/*; do
	[ "$(basename "$(readlink -f $i/device/driver)")" = mlx5_core ] && ethtool -A ${i##*/} rx off tx off || true
done
echo SETUP-OK
