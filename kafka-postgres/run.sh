#!/usr/bin/env bash
# The Kafka-Postgres use case, end to end: start both services, seed a
# table, move its rows to a topic, move the topic's messages into a second
# table, compare that table with the mock events, and stop both.
set -euo pipefail
cd "$(dirname "$0")"
source ../bin/hql-bin.sh

export DEMO_DSN="host=localhost port=55432 user=hql password=hql dbname=demo"
export KAFKA_BROKERS=localhost:59092
trap 'docker compose down -v >/dev/null 2>&1' EXIT
docker compose up -d --wait postgres kafka >/dev/null 2>&1
docker compose run --rm topics >/dev/null 2>&1

for program in seed.hql postgres-to-kafka.hql kafka-to-postgres.hql; do
  "$HQL" run --to none "$program"
  echo "ok   $program"
done
expect archive.hql expected/archive.json
