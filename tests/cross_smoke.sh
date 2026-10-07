#!/bin/zsh
# Cross-platform online race: L players run on Linux (arm64, in a Lima VM) and M on this Mac, all in
# one match over the lobby, and every one of them must see all the others race (tests/race_smoke.gd).
# Usage: tests/cross_smoke.sh [linux=2] [mac=2] [lobby=wss://gokart.games/api/mp] [--finish|--items]
# Needs Lima (brew install lima). The first run creates the VM "gokart" (Ubuntu) and downloads the
# Linux build of the same Godot version; every run copies the committed tree (git HEAD) into it.
cd "$(dirname "$0")/.."
nl=${1:-2}
nm=${2:-2}
lobby=${3:-wss://gokart.games/api/mp}
extra=$4
n=$(( nl + nm ))
vm=gokart
ver=$(godot --version | sed -E 's/^([0-9.]+)\.stable.*/\1/')
gd="Godot_v${ver}-stable_linux.arm64"
limit=150; [[ -n $extra ]] && limit=400
if ! limactl list -q 2>/dev/null | grep -qx $vm; then
  limactl start --name=$vm --tty=false --cpus=4 --memory=4 template:ubuntu-lts || exit 1
fi
limactl list $vm | grep -q Running || limactl start $vm || exit 1
limactl shell $vm -- bash -lc "test -x ~/$gd || (sudo apt-get install -y unzip >/dev/null && curl -sSL -o ~/g.zip https://github.com/godotengine/godot/releases/download/${ver}-stable/${gd}.zip && unzip -o -q ~/g.zip -d ~)" || exit 1
# the VM sees the Mac's home folder read-only: hand the tree over through it, import inside the VM
tar=$HOME/.gokart_cross.tar
git archive --format=tar HEAD > $tar
limactl shell $vm -- bash -lc "rm -rf ~/gk && mkdir ~/gk && tar -xf $tar -C ~/gk && cd ~/gk && ~/$gd --headless --import --path . > /tmp/gk_import.log 2>&1" || exit 1
rm -f $tar
names=(Linus Lena Lars Liv Macy Moe Mia Max)
lin=(); mac=()
for i in $(seq 1 $nl); do lin+=${names[$i]}; done
for i in $(seq 1 $nm); do mac+=${names[$(( i + 4 ))]}; done
limactl shell $vm -- bash -lc "cd ~/gk; for p in $lin; do GOKART_LOBBY=$lobby perl -e 'alarm $limit; exec @ARGV' -- ~/$gd --headless --path . -s tests/race_smoke.gd -- --name=\$p --players=$n $extra > /tmp/gokart_cross_\$p.log 2>&1 & sleep 0.5; done; fail=0; for j in \$(jobs -p); do wait \$j || fail=1; done; exit \$fail" &
lpid=$!
sleep 3
pids=()
for p in $mac; do
  GOKART_LOBBY=$lobby perl -e "alarm $limit; exec @ARGV" -- godot --headless --path . -s tests/race_smoke.gd -- --name=$p --players=$n $extra > /tmp/gokart_cross_$p.log 2>&1 &
  pids+=$!
  sleep 0.5
done
fail=0
wait $lpid || fail=1
for pid in $pids; do wait $pid || fail=1; done
pat=": (race|sees|items|OK|FAILED|TIMEOUT|board|FINISH)"
for p in $lin; do limactl shell $vm -- bash -lc "grep -E '^$p$pat' /tmp/gokart_cross_$p.log | sed 's/^/[linux] /'"; done
for p in $mac; do grep -E "^$p$pat" /tmp/gokart_cross_$p.log | sed 's/^/[macos] /'; done
[[ $fail == 0 ]] && echo "CROSS SMOKE: $nl Linux + $nm macOS players OK" || echo "CROSS SMOKE: FAILED"
exit $fail
