#!/usr/bin/env bash
# The NATS use case, end to end: start the server, publish the mock events
# to a subject, read them back from the stream, by id and by a transport
# written in the program, compare; read them through a durable consumer
# twice, the second read finding nothing new; and stop the server.
set -euo pipefail
cd "$(dirname "$0")"
source ../bin/hql-bin.sh

export NATS_URL=nats://localhost:54222
trap 'docker compose down -v >/dev/null 2>&1' EXIT
up nats
once streams

run produce.hql
expect consume.hql expected/consume.json
expect by-constructor.hql expected/by-constructor.json
expect resume.hql expected/resume-first.json
expect resume.hql expected/resume-again.json
