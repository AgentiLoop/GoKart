#!/bin/zsh
# Cross-platform online race: L players run on Linux (arm64, in a Lima VM) and M on this Mac, all in
# one match over the lobby, and every one of them must see all the others race (tests/race_smoke.gd).
# Usage: tests/cross_smoke.sh [linux=2] [mac=2] [lobby=wss://gokart.games/api/mp] [--finish|--items]
# GOKART_WINDOWS=W adds W players on Windows: Godot's Windows arm64 build under Wine in the same VM.
# Needs Lima (brew install lima). The first run creates the VM "gokart" (Ubuntu) and downloads the
# Linux build of the same Godot version; every run copies the committed tree (git HEAD) into it.
# The first Windows run also builds Wine (WINE_VER below, ~20 min) and downloads the Windows Godot:
# Ubuntu's Wine 10 hangs in wineboot on Apple M-series VMs, newer Wine works.
cd "$(dirname "$0")/.."
nl=${1:-2}
nm=${2:-2}
lobby=${3:-wss://gokart.games/api/mp}
extra=$4
nw=${GOKART_WINDOWS:-0}
n=$(( nl + nm + nw ))
vm=gokart
ver=$(godot --version | sed -E 's/^([0-9.]+)\.stable.*/\1/')
gd="Godot_v${ver}-stable_linux.arm64"
gw="Godot_v${ver}-stable_windows_arm64_console.exe"
WINE_VER=11.19
limit=150; [[ -n $extra ]] && limit=400
if ! limactl list -q 2>/dev/null | grep -qx $vm; then
  limactl start --name=$vm --tty=false --cpus=4 --memory=4 template:ubuntu-lts || exit 1
fi
limactl list $vm | grep -q Running || limactl start $vm || exit 1
limactl shell $vm -- bash -lc "test -x ~/$gd || (sudo apt-get install -y unzip >/dev/null && curl -sSL -o ~/g.zip https://github.com/godotengine/godot/releases/download/${ver}-stable/${gd}.zip && unzip -o -q ~/g.zip -d ~)" || exit 1
if (( nw > 0 )); then
  limactl shell $vm -- bash -lc "test -x ~/wine11/bin/wine || (set -e
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq build-essential flex bison clang lld llvm gettext libgnutls28-dev pkg-config xz-utils unzip > /dev/null
    cd ~ && curl -sSL https://dl.winehq.org/wine/source/11.x/wine-$WINE_VER.tar.xz | tar -xJ && cd wine-$WINE_VER
    ./configure --prefix=\$HOME/wine11 --enable-archs=aarch64 --disable-tests --without-x --without-freetype --without-wayland --without-vulkan --without-opengl --without-alsa --without-pulse --without-gstreamer --without-cups --without-sane --without-usb --without-v4l2 --without-dbus --without-krb5 --without-netapi --without-pcap > /tmp/wine_conf.log 2>&1
    make -j3 > /tmp/wine_make.log 2>&1 && make install > /dev/null 2>&1
    WINEDEBUG=-all ~/wine11/bin/wine wineboot -i > /dev/null 2>&1)
    test -f ~/$gw || (curl -sSL -o ~/gw.zip https://github.com/godotengine/godot/releases/download/${ver}-stable/Godot_v${ver}-stable_windows_arm64.exe.zip && unzip -o -q ~/gw.zip -d ~)" || exit 1
fi
# the VM sees the Mac's home folder read-only: hand the tree over through it, import inside the VM
tar=$HOME/.gokart_cross.tar
git archive --format=tar HEAD > $tar
limactl shell $vm -- bash -lc "rm -rf ~/gk ~/gkw && mkdir ~/gk && tar -xf $tar -C ~/gk && cd ~/gk && ~/$gd --headless --import --path . > /tmp/gk_import.log 2>&1 && cp -r ~/gk ~/gkw" || exit 1
rm -f $tar
names=(Linus Lena Lars Liv Macy Moe Mia Max Wendy Walt Wren Will)
lin=(); mac=(); win=()
for i in $(seq 1 $nl); do lin+=${names[$i]}; done
for i in $(seq 1 $nm); do mac+=${names[$(( i + 4 ))]}; done
for i in $(seq 1 $nw); do win+=${names[$(( i + 8 ))]}; done
lpid=; wpid=
if (( nl > 0 )); then
  limactl shell $vm -- bash -lc "cd ~/gk; for p in $lin; do GOKART_LOBBY=$lobby perl -e 'alarm $limit; exec @ARGV' -- ~/$gd --headless --path . -s tests/race_smoke.gd -- --name=\$p --players=$n $extra > /tmp/gokart_cross_\$p.log 2>&1 & sleep 0.5; done; fail=0; for j in \$(jobs -p); do wait \$j || fail=1; done; exit \$fail" &
  lpid=$!
fi
if (( nw > 0 )); then
  # Godot under Wine never exits after quit(): judge each Windows player by its log, then stop Wine
  limactl shell $vm -- bash -lc "cd ~/gkw; export PATH=\$HOME/wine11/bin:\$PATH WINEDEBUG=-all GOKART_LOBBY=$lobby; for p in $win; do perl -e 'alarm $limit; exec @ARGV' -- wine ~/$gw --headless --path . -s tests/race_smoke.gd -- --name=\$p --players=$n $extra > /tmp/gokart_cross_\$p.log 2>&1 & sleep 0.5; done; fail=0; for p in $win; do s=0; until grep -qaE \"^\$p: (OK|FAILED|TIMEOUT)\" /tmp/gokart_cross_\$p.log || (( s >= $limit )); do sleep 1; s=\$(( s + 1 )); done; grep -qa \"^\$p: OK\" /tmp/gokart_cross_\$p.log || fail=1; done; sleep 3; wineserver -k; exit \$fail" &
  wpid=$!
fi
sleep 3
pids=()
for p in $mac; do
  GOKART_LOBBY=$lobby perl -e "alarm $limit; exec @ARGV" -- godot --headless --path . -s tests/race_smoke.gd -- --name=$p --players=$n $extra > /tmp/gokart_cross_$p.log 2>&1 &
  pids+=$!
  sleep 0.5
done
fail=0
[[ -n $lpid ]] && { wait $lpid || fail=1; }
[[ -n $wpid ]] && { wait $wpid || fail=1; }
for pid in $pids; do wait $pid || fail=1; done
pat=": (race|sees|items|OK|FAILED|TIMEOUT|board|FINISH)"
for p in $lin; do limactl shell $vm -- bash -lc "grep -E '^$p$pat' /tmp/gokart_cross_$p.log | sed 's/^/[linux] /'"; done
for p in $win; do limactl shell $vm -- bash -lc "grep -aE '^$p$pat' /tmp/gokart_cross_$p.log | sed 's/^/[windows] /'"; done
for p in $mac; do grep -E "^$p$pat" /tmp/gokart_cross_$p.log | sed 's/^/[macos] /'; done
[[ $fail == 0 ]] && echo "CROSS SMOKE: $nl Linux + $nw Windows + $nm macOS players OK" || echo "CROSS SMOKE: FAILED"
exit $fail

