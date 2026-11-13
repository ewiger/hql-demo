#!/usr/bin/env bash
# The core NATS use case, end to end: start a server without JetStream,
# start a subscriber, publish the mock events to a subject per kind,
# compare what the subscriber was given, and stop the server.
set -euo pipefail
cd "$(dirname "$0")"
source ../bin/hql-bin.sh

export NATS_URL=nats://localhost:54223
out="$(mktemp)"
trap 'rm -f "$out" "$out.err"; docker compose down -v >/dev/null 2>&1' EXIT
up nats

# A core subject keeps nothing: the subscriber must be listening before
# anything is published.
"$HQL" run --to json --compact subscribe.hql >"$out" 2>"$out.err" &
subscriber=$!
sleep 1
run publish.hql
if ! wait "$subscriber"; then
  fail subscribe.hql "$HQL run --to json --compact subscribe.hql" "$(cat "$out.err")"
  exit 1
fi
check subscribe.hql expected/subscribe.json cat "$out"
