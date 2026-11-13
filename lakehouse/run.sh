#!/usr/bin/env bash
# The lakehouse use case, end to end: start MinIO and the Spark Thrift
# Server, write the mock events to a Delta table, read them back as a
# report, compare, and stop both. The first run builds the Spark image,
# which fetches about 300 MB of jars.
set -euo pipefail
cd "$(dirname "$0")"
source ../bin/hql-bin.sh

export LAKEHOUSE_URL=http://localhost:50001/cliservice
trap 'docker compose down -v >/dev/null 2>&1' EXIT
up minio
once buckets
up spark

run load.hql
expect report.hql expected/report.json
