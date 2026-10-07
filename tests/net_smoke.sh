#!/bin/zsh
# Runs N (2-4) headless GoKart instances against a lobby and checks they all reach each other
# peer-to-peer. Usage: tests/net_smoke.sh [players=3] [lobby=ws://localhost:8787/api/mp]
# (start a local lobby with: cd website && npx wrangler dev --port 8787)
cd "$(dirname "$0")/.."
n=${1:-3}
export GOKART_LOBBY=${2:-ws://localhost:8787/api/mp}
names=(Alice Bob Carol Dave)
pids=()
for i in $(seq 1 $n); do
  perl -e 'alarm 90; exec @ARGV' -- godot --headless --path . -s tests/net_smoke.gd -- --name=${names[$i]} --players=$n > /tmp/gokart_net_$i.log 2>&1 &
  pids+=$!
  sleep 0.5
done
fail=0
for i in $(seq 1 $n); do
  wait ${pids[$i]} || fail=1
  grep -E ": (start|got|OK|FAILED|TIMEOUT)" /tmp/gokart_net_$i.log
done
[[ $fail == 0 ]] && echo "NET SMOKE: $n players OK" || echo "NET SMOKE: FAILED"
exit $fail
