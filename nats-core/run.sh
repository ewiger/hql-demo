#!/usr/bin/env bash
# The core NATS use case, end to end: start a server without JetStream,
# start a subscriber, publish the mock events to a subject per kind,
# compare what the subscriber was given, and stop the server.
set -euo pipefail
cd "$(dirname "$0")"
source ../bin/hql-bin.sh

export NATS_URL=nats://localhost:54223
out="$(mktemp)"
trap 'rm -f "$out"; docker compose down -v >/dev/null 2>&1' EXIT
docker compose up -d --wait nats >/dev/null 2>&1

# A core subject keeps nothing: the subscriber must be listening before
# anything is published.
"$HQL" run --to json --compact subscribe.hql >"$out" &
subscriber=$!
sleep 1
"$HQL" run --to none publish.hql
echo "ok   publish.hql"
wait "$subscriber"
if [ "$(cat "$out")" = "$(cat expected/subscribe.json)" ]; then
  echo "ok   subscribe.hql"
else
  echo "FAIL subscribe.hql" >&2
  diff "$out" expected/subscribe.json >&2 || true
  exit 1
fi
