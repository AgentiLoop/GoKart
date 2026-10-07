#!/bin/zsh
# Runs N (2-4) headless GoKart instances through the ONLINE screen (Quick Match, host presses START NOW)
# and checks each one reaches the online race scene. Usage: tests/lobby_smoke.sh [players=3] [lobby=ws://localhost:8787/api/mp]
# (start a local lobby with: cd website && npx wrangler dev --port 8787)
cd "$(dirname "$0")/.."
n=${1:-3}
export GOKART_LOBBY=${2:-ws://localhost:8787/api/mp}
names=(Alice Bob Carol Dave)
pids=()
for i in $(seq 1 $n); do
  perl -e 'alarm 70; exec @ARGV' -- godot --headless --path . -s tests/lobby_smoke.gd -- --name=${names[$i]} --players=$n > /tmp/gokart_lobby_$i.log 2>&1 &
  pids+=$!
  sleep 0.5
done
fail=0
for i in $(seq 1 $n); do
  wait ${pids[$i]} || fail=1
  grep -E ": (pressed|lobby|race|OK|FAILED|TIMEOUT)" /tmp/gokart_lobby_$i.log
done
[[ $fail == 0 ]] && echo "LOBBY SMOKE: $n players OK" || echo "LOBBY SMOKE: FAILED"
exit $fail
