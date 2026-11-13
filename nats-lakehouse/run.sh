#!/usr/bin/env bash
# The NATS-lakehouse use case, end to end: start NATS, MinIO and the Spark
# Thrift Server; publish raw events to a subject; route each into the
# silver Delta table or the dead-letter subject; total the silver table
# into the gold Delta table; compare all three with what is expected; and
# stop everything.
set -euo pipefail
cd "$(dirname "$0")"
source ../bin/hql-bin.sh

export NATS_URL=nats://localhost:54222
export LAKEHOUSE_URL=http://localhost:50001/cliservice
trap 'docker compose down -v >/dev/null 2>&1' EXIT
up nats minio
once streams
once buckets
up spark

run produce-raw.hql ingest.hql revenue.hql
expect silver.hql expected/silver.json
expect gold.hql expected/gold.json
expect rejected.hql expected/rejected.json
