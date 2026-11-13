#!/usr/bin/env bash
# Run every use case in turn; each starts its own containers and stops them.
set -euo pipefail
cd "$(dirname "$0")"
for case in kafka postgres kafka-postgres ledger nats nats-core lakehouse nats-lakehouse; do
  echo "== $case"
  "./$case/run.sh"
done
