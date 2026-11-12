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
| [`kafka-postgres/`](kafka-postgres/) | both | Postgres to Kafka: a table's rows to a topic. Kafka to Postgres: the topic's messages into a second table. Quarantine: raw messages routed into a clean table or a quarantine table, with reasons |

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

## Quarantine

Reading a topic as a declared type is strict: the first message that is not
an `Event` is an evaluation failure naming the endpoint and the message, and
the stream stops. A pipeline that must keep running reads the topic as
`Data`, validates each message against a contract, and routes the two sides
to two sinks. `validate` gives one `Result` per message, holding the value
or the message as it arrived with every violation; `fork` writes each result
to one side, in source order, and ends neither:

```hql
type EventData : DataContract = {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String

    require amount >= 0 as non_negative
    require ["order_placed", "order_shipped", "payment_failed"] | contains(kind) as known_kind
}

tap("order_events_raw")
| validate(EventData)
| fork {
    clean      = oks()  | map(e => Event(…)) | sink("order_clean"),
    quarantine = errs() | map(e => Rejected(…)) | sink("order_quarantine"),
}
```

The quarantine table holds the message as the producer sent it and the rules
it broke, `EventData.amount.type`, `EventData.customer.missing`,
`EventData.non_negative`, so a rejected message can be repaired and replayed.
The contract is the policy; the shape of the pipeline is what happens to a
message that breaks it. [`kafka-postgres/quarantine.hql`](kafka-postgres/quarantine.hql)
is the whole program.

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
hql run produce-raw.hql
hql run quarantine.hql
hql run clean.hql
hql run rejected.hql
docker compose down -v
```
