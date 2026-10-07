#!/bin/zsh
# Online race between EXPORTED release builds (what players download), not the Godot editor:
# L Linux arm64 and W Windows arm64 players in the Lima VM (Windows under Wine) and M macOS players
# here, all in one match over the lobby; every one must see all the others race (tests/race_smoke.gd,
# started through `GoKart -- --smoke=res://tests/race_smoke.gd` because export templates ignore -s).
# Usage: tests/export_smoke.sh [linux=1] [windows=1] [mac=2] [lobby=wss://gokart.games/api/mp] [--finish|--items]
# Needs the VM, Godot and Wine that tests/cross_smoke.sh sets up (run GOKART_WINDOWS=1 tests/cross_smoke.sh once)
# and the export templates. Exports the committed tree (git HEAD); Windows uses the Windows preset
# switched to arm64 (the VM can't run x86_64).
cd "$(dirname "$0")/.."
nl=${1:-1}
nw=${2:-1}
nm=${3:-2}
lobby=${4:-wss://gokart.games/api/mp}
extra=$5
n=$(( nl + nw + nm ))
vm=gokart
limit=150; [[ -n $extra ]] && limit=400
src=$(mktemp -d /tmp/gokart_export.XXXX)
out=$HOME/.gokart_export
rm -rf $out && mkdir -p $out/{mac,linux,windows}
git archive --format=tar HEAD | tar -xf - -C $src
sed -i '' '/^name="Windows"/,/^\[preset\.2\]/s/^binary_format\/architecture="x86_64"/binary_format\/architecture="arm64"/' $src/export_presets.cfg
godot --headless --path $src --import > /tmp/gokart_export.log 2>&1
for p in "macOS:mac/GoKart.app" "Linux arm64:linux/GoKart.arm64" "Windows:windows/GoKart.exe"; do
  godot --headless --path $src --export-release "${p%%:*}" "$out/${p#*:}" >> /tmp/gokart_export.log 2>&1 || { echo "export ${p%%:*} failed"; exit 1; }
done
rm -rf $src
ls $out/linux $out/windows
limactl list $vm | grep -q Running || limactl start $vm || exit 1
limactl shell $vm -- bash -lc "rm -rf ~/gkx /tmp/gokart_export_*.log && cp -r $out ~/gkx" || exit 1
names=(Lotte Leif Lou Lux Wade Wanda Wes Wynn Mabel Milo Mira Mats)
lin=(); win=(); mac=()
for i in $(seq 1 $nl); do lin+=${names[$i]}; done
for i in $(seq 1 $nw); do win+=${names[$(( i + 4 ))]}; done
for i in $(seq 1 $nm); do mac+=${names[$(( i + 8 ))]}; done
args="--players=$n $extra"
lpid=; wpid=
if (( nl > 0 )); then
  limactl shell $vm -- bash -lc "for p in $lin; do GOKART_LOBBY=$lobby perl -e 'alarm $limit; exec @ARGV' -- ~/gkx/linux/GoKart.arm64 --headless -- --smoke=res://tests/race_smoke.gd --name=\$p $args > /tmp/gokart_export_\$p.log 2>&1 & sleep 0.5; done; fail=0; for j in \$(jobs -p); do wait \$j || fail=1; done; exit \$fail" &
  lpid=$!
fi
if (( nw > 0 )); then
  # Godot under Wine never exits after quit(): judge each Windows player by its log, then stop Wine
  ok=OK; [[ $extra == --finish ]] && ok="FINISH OK"
  limactl shell $vm -- bash -lc "export PATH=\$HOME/wine11/bin:\$PATH WINEDEBUG=-all GOKART_LOBBY=$lobby; for p in $win; do perl -e 'alarm $limit; exec @ARGV' -- wine ~/gkx/windows/GoKart.exe --headless -- --smoke=res://tests/race_smoke.gd --name=\$p $args > /tmp/gokart_export_\$p.log 2>&1 & sleep 0.5; done; fail=0; for p in $win; do s=0; until grep -qaE \"^\$p: ($ok|FAILED|TIMEOUT)\" /tmp/gokart_export_\$p.log || (( s >= $limit )); do sleep 1; s=\$(( s + 1 )); done; grep -qa \"^\$p: $ok\" /tmp/gokart_export_\$p.log || fail=1; done; sleep 4; wineserver -k; exit \$fail" &
  wpid=$!
fi
sleep 3
pids=()
for p in $mac; do
  GOKART_LOBBY=$lobby perl -e "alarm $limit; exec @ARGV" -- $out/mac/GoKart.app/Contents/MacOS/GoKart --headless -- --smoke=res://tests/race_smoke.gd --name=$p ${=args} > /tmp/gokart_export_$p.log 2>&1 &
  pids+=$!
  sleep 0.5
done
fail=0
[[ -n $lpid ]] && { wait $lpid || fail=1; }
[[ -n $wpid ]] && { wait $wpid || fail=1; }
for pid in $pids; do wait $pid || fail=1; done
pat=": (race|sees|items|OK|FAILED|TIMEOUT|board|FINISH)"
for p in $lin; do limactl shell $vm -- bash -lc "grep -aE '^$p$pat' /tmp/gokart_export_$p.log | sed 's/^/[linux export] /'"; done
for p in $win; do limactl shell $vm -- bash -lc "grep -aE '^$p$pat' /tmp/gokart_export_$p.log | sed 's/^/[windows export] /'"; done
for p in $mac; do grep -aE "^$p$pat" /tmp/gokart_export_$p.log | sed 's/^/[macos export] /'; done
if [[ $extra == --finish ]]; then
  limactl shell $vm -- bash -lc "! grep -aqE '^[A-Za-z]+: board .* LEFT' /tmp/gokart_export_*.log" || fail=1
  for p in $mac; do grep -qaE "^$p: board .* LEFT" /tmp/gokart_export_$p.log && fail=1; done
fi
[[ $fail == 0 ]] && echo "EXPORT SMOKE: $nl Linux + $nw Windows + $nm macOS exported players OK" || echo "EXPORT SMOKE: FAILED"
exit $fail
