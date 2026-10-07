#!/bin/zsh
# Runs N (2-4) headless GoKart instances against a lobby and checks they all reach each other
# peer-to-peer and race: every kart sees the others drive. Usage: tests/race_smoke.sh [players=3] [lobby=ws://localhost:8787/api/mp]
# Add a third argument --finish to race all 3 laps and check every board has everyone's time.
# (start a local lobby with: cd website && npx wrangler dev --port 8787)
cd "$(dirname "$0")/.."
n=${1:-3}
export GOKART_LOBBY=${2:-ws://localhost:8787/api/mp}
names=(Alice Bob Carol Dave)
limit=100; [[ -n $3 ]] && limit=400
pids=()
for i in $(seq 1 $n); do
  perl -e "alarm $limit; exec @ARGV" -- godot --headless --path . -s tests/race_smoke.gd -- --name=${names[$i]} --players=$n $3 > /tmp/gokart_race_$i.log 2>&1 &
  pids+=$!
  sleep 0.5
done
fail=0
for i in $(seq 1 $n); do
  wait ${pids[$i]} || fail=1
  grep -E ": (race|GO|sees|OK|FAILED|TIMEOUT|board)" /tmp/gokart_race_$i.log
done
[[ $fail == 0 ]] && echo "RACE SMOKE: $n players OK" || echo "RACE SMOKE: FAILED"
exit $fail
