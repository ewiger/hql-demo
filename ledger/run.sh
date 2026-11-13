#!/usr/bin/env bash
# The ledger use case, end to end: start the server, seed two accounts,
# transfer 100 twice, which commits, and a third time, which rolls back on
# the sender's balance; read the ledger back. Then race: seed the sender
# with 150, start two transfers of 100 at once, and check that exactly one
# commits, the other fails as data, and no balance goes negative. Stop the
# server.
set -euo pipefail
cd "$(dirname "$0")"
source ../bin/hql-bin.sh

export DEMO_DSN="host=localhost port=55432 user=hql password=hql dbname=demo"
race="$(mktemp -d)"
trap 'rm -rf "$race"; docker compose down -v >/dev/null 2>&1' EXIT
up postgres

run seed.hql
expect transfer.hql expected/transferred.json "transfer.hql, the first"
expect transfer.hql expected/transferred.json "transfer.hql, the second"
expect transfer.hql expected/rolled-back.json "transfer.hql, the third"
expect report.hql expected/report.json

# Two concurrent withdrawals of 100 from 150, under `Serializable` with
# three attempts. Which one wins is not fixed; that exactly one does is.
# The loser ends `rolled_back` on the balance check after a retry, or
# `conflict` if its attempts run out.
run seed-race.hql
for side in a b; do
  "$HQL" run --to json --compact transfer.hql >"$race/$side" 2>"$race/$side.err" &
  eval "pid_$side=\$!"
done
for side in a b; do
  eval "pid=\$pid_$side"
  if ! wait "$pid"; then
    fail "transfer.hql, racer $side" "$HQL run --to json --compact transfer.hql" "$(cat "$race/$side.err")"
    exit 1
  fi
done
outcomes="$(sort "$race/a" "$race/b")"
winners="$(grep -cx '"transferred"' <<<"$outcomes" || true)"
losers="$(grep -cxE '"(rolled_back: insufficient balance|conflict: .*)"' <<<"$outcomes" || true)"
if [ "$winners" = 1 ] && [ "$losers" = 1 ]; then
  echo "ok   transfer.hql, two at once: one committed, one $(grep -vx '"transferred"' <<<"$outcomes")"
else
  fail "transfer.hql, two at once" "two concurrent runs of $HQL run --to json --compact transfer.hql" \
    "$(cat "$race/a.err" "$race/b.err")" \
    "expected one \"transferred\" and one rolled_back or conflict; got:
$outcomes"
  exit 1
fi
expect report.hql expected/race-report.json "report.hql, after the race"
