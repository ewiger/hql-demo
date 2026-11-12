#!/usr/bin/env bash
# The Kafka use case, end to end: start the broker, write the mock events
# to a topic, read them back, compare, and stop the broker.
set -euo pipefail
cd "$(dirname "$0")"
source ../bin/hql-bin.sh

export KAFKA_BROKERS=localhost:59092
trap 'docker compose down -v >/dev/null 2>&1' EXIT
docker compose up -d --wait kafka >/dev/null 2>&1
docker compose run --rm topics >/dev/null 2>&1

"$HQL" run --to none produce.hql
echo "ok   produce.hql"
expect consume.hql expected/consume.json
