IF=ens4f1np1
L=/root/trx.log
snap() { ethtool -S $IF | sed 's/^ *//; s/: / /' > $1; }
d() { awk -v k=$1 'NR==FNR{if($1==k)a=$2;next} $1==k{b=$2} END{printf "%d", b-a}' /root/s0 /root/s1; }
g() { grep -oP "$1" $L | head -1; }
t() { grep 'Total: received' $L | sed -n "s/.*$1 \([0-9]*\).*/\1/p" | head -1; }
snap /root/s0
cd /root/MoonGen && ./build/MoonGen examples/ipsec/ipsec-transceiver.lua 1 --tx-cores $T --rx-cores $R -s $S -t $D -r $RATE --tunnel-local $LOCAL --tunnel-remote $REMOTE $X > $L 2>&1
snap /root/s1
nz=$(awk 'NR==FNR{a[$1]=$2;next} ($2-a[$1])!=0 && $1 ~ /discard|drop|err|out_of|buf|pause/ {printf "%s=%d,", $1, $2-a[$1]}' /root/s0 /root/s1)
echo "RES sent=$(g 'packets sent: \K[0-9]+') rate=$(g 'packets sent: [0-9]+, rate \K[0-9.]+') recv=$(t 'Total: received') ok=$(t 'authenticated') auth=$(t 'ICV failures') miss=$(t 'missing in between') drop=$(g 'queue was full \K[0-9]+') warn=$(grep -c 'reached only' $L) err=$(grep -c -E 'FATAL|ERROR' $L) txphy=$(d tx_packets_phy) rxphy=$(d rx_packets_phy) fc=$(ethtool -a $IF | awk '/^RX:|^TX:/{printf "%s", $2}') nz=$nz"
echo "DIAG tx: $(grep -oP 'Core \d+: SPI \d+, packets sent \d+, largest backlog [0-9.]+ ms at [0-9.]+ s, catch-up phases \d+' $L | awk '{gsub(":","",$2); if ($10+0 > 0.3) printf "c%s/spi%d:%sms@%ss/%sph ", $2, $4+0, $10, $13, $17; ph+=$17; if ($10+0>m) m=$10+0} END{printf "| maxlag=%.3fms phases=%d", m, ph}')"
echo "DIAG rx: $(grep -oP 'Queue \d+: longest pause between two receive calls [0-9.]+ ms at [0-9.]+ s' $L | awk '{gsub(":","",$2); if ($9+0 > 0.3) printf "q%s:%sms@%ss ", $2, $9, $12; if ($9+0>m) m=$9+0} END{printf "| maxpause=%.3fms", m}')"
echo "DIAG miss: $(grep -oP 'SPI \d+: ESP sequence numbers \d+\.\.\d+, received \d+, missing in between \d+' $L | awk '{gsub(":","",$2); if ($12+0 > 0) printf "spi%s:%s ", $2, $12}')"
echo TRX-DONE
