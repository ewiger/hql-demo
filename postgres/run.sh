#!/usr/bin/env bash
# The Postgres use case, end to end: start the server, write the mock
# events to a table, read them back as a report, compare, and stop it.
set -euo pipefail
cd "$(dirname "$0")"
source ../bin/hql-bin.sh

export DEMO_DSN="host=localhost port=55432 user=hql password=hql dbname=demo"
trap 'docker compose down -v >/dev/null 2>&1' EXIT
docker compose up -d --wait postgres >/dev/null 2>&1

"$HQL" run --to none load.hql
echo "ok   load.hql"
expect report.hql expected/report.json
