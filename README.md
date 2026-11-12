# hql-demo

Use cases for [HQL](https://github.com/ewiger/hql) against real systems, each
in its own folder with the Docker Compose file that starts what it needs. A
folder is an HQL vault: its `hql.toml` configures the endpoints its programs
read and write by id, and its `run.sh` runs the case end to end and compares
the output with `expected/`.

| Folder | Services | What the programs do |
| --- | --- | --- |
| [`kafka/`](kafka/) | Kafka 3.9 | Write the mock events from `events.json` to a topic, one message each, then read the topic back |
| [`postgres/`](postgres/) | PostgreSQL 17 | Write the mock events to a table, then read it back as a report per customer |
| [`kafka-postgres/`](kafka-postgres/) | both | Postgres to Kafka: a table's rows to a topic. Kafka to Postgres: the topic's messages into a second table |

## Running

You need Docker with Compose, and an `hql` binary built from the sibling
`hql` repository (`cargo build` there) or on the `PATH`; set `HQL` to use
another one.

```sh
./run-all.sh            # every case
./kafka/run.sh          # one case
```

Each case starts its containers, runs its programs, and removes the
containers and their volumes when it ends. The host ports are 59092 for
Kafka and 55432 for PostgreSQL.

## Source and tap

A table ends, so a program reads it by `source`, as a `Seq`. A topic is a log
that does not end, so a program reads it by `tap`, as a `Stream`, and
`source` of a topic is a type error. The topics here set `idle_ms`, so a
stream ends once the topic has been idle that long and the programs
terminate.

```hql
orders : Seq<Event> = source("orders")      // a table: every row, then the end
orders | sink("order_events")                // a message per row

events : Stream<Event> = tap("order_events") // a topic: each message as it arrives
events | sink("order_archive")               // a row per message, committed as it comes
```

## Running a program by hand

Start a case's services and set the variables its `hql.toml` names:

```sh
cd kafka-postgres
docker compose up -d --wait postgres kafka
docker compose run --rm topics
export DEMO_DSN="host=localhost port=55432 user=hql password=hql dbname=demo"
export KAFKA_BROKERS=localhost:59092
hql run seed.hql
hql run postgres-to-kafka.hql
hql run kafka-to-postgres.hql
hql run archive.hql
docker compose down -v
```
