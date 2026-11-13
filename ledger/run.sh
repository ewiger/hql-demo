#!/usr/bin/env bash
# The ledger use case, end to end: start the server, seed two accounts,
# transfer 100 twice, which commits, and a third time, which rolls back on
# the sender's balance; read the ledger back; and stop the server.
set -euo pipefail
cd "$(dirname "$0")"
source ../bin/hql-bin.sh

export DEMO_DSN="host=localhost port=55432 user=hql password=hql dbname=demo"
trap 'docker compose down -v >/dev/null 2>&1' EXIT
docker compose up -d --wait postgres >/dev/null 2>&1

"$HQL" run --to none seed.hql
echo "ok   seed.hql"
expect transfer.hql expected/transferred.json
expect transfer.hql expected/transferred.json
expect transfer.hql expected/rolled-back.json
expect report.hql expected/report.json
