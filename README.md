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
| [`nats/`](nats/) | NATS 2.11 with JetStream | Publish the mock events to a subject, one message each, then read the subject back from its stream |
| [`lakehouse/`](lakehouse/) | Spark 3.5, Delta Lake 3.3, MinIO | Write the mock events to a Delta table, then read it back as a report per customer |
| [`nats-lakehouse/`](nats-lakehouse/) | all of the above | Raw messages on a subject routed into a silver Delta table or a dead-letter subject, then the silver table totalled into a gold Delta table |

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
Kafka, 55432 for PostgreSQL, 54222 for NATS and 50001 for the Spark SQL
endpoint.

The NATS and lakehouse cases need an `hql` built from the
`feat/nats-lakehouse` branch or later, which has the `nats` and `spark`
kinds. The first lakehouse run builds an image of Spark with Delta Lake and
the S3 connector; the build downloads about 300 MB of jars, once.

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

## Subjects and lakehouse tables

NATS and a lakehouse sit on the same two sides of that line. A JetStream
stream keeps the messages published to its subjects, so a subject is a log:
`kind = "nats"` is read by `tap` and written by `sink`, and each message is
written once the stream acknowledges it. A lakehouse table ends:
`kind = "spark"` is read by `source` and written by `target` or `sink`.

```toml
[endpoint.orders_raw]
kind = "nats"
url_env = "NATS_URL"
stream = "ORDERS"
subject = "orders.raw"
idle_ms = 2000

[endpoint.orders_silver]
kind = "spark"
url_env = "LAKEHOUSE_URL"
table = "default.orders_silver"
order = ["id"]
mode = "append"
```

### The lakehouse

The `spark` kind speaks HiveServer2's Thrift protocol over HTTP. A
Databricks SQL warehouse answers it, and so does the Thrift Server of
open-source Spark, so the same `hql.toml` and the same programs run against
either. What runs here is the open-source stack:

```text
            hql ──HTTP, Thrift──▶ Spark Thrift Server ──S3 API──▶ MinIO
  kind = "spark"                  Spark 3.5 + Delta Lake 3.3      bucket `lakehouse`
                                  localhost:50001/cliservice      warehouse/<table>/_delta_log/…
```

[`lakehouse/spark/`](lakehouse/spark/) is the image: `apache/spark` with the
Delta Lake and S3 connector jars and a `spark-defaults.conf` that makes
Delta the format of every table and a MinIO bucket the warehouse. Every
table a program writes is a Delta table: a folder of Parquet files and a
transaction log in the bucket.

MinIO publishes no container image of its own any longer, so the Compose
files use Chainguard's build of the same server,
`cgr.dev/chainguard/minio:latest-dev`. Only its newest build is public, so
the tag is not pinned to a release.

### Databricks

To run [`lakehouse/`](lakehouse/) against a Databricks workspace, the Free
Edition included, point the endpoint at a SQL warehouse instead of the local
server:

1. In the workspace, open the SQL warehouse's connection details and copy
   its server hostname and HTTP path, and create a personal access token.
2. In [`lakehouse/hql.toml`](lakehouse/hql.toml), uncomment
   `token_env = "LAKEHOUSE_TOKEN"`, and set `table` to a table of a catalog
   and schema you may write, `workspace.default.events`.
3. Run the programs with both variables set:

```sh
cd lakehouse
export LAKEHOUSE_URL="https://<server hostname><http path>"   # https://dbc-….cloud.databricks.com/sql/1.0/warehouses/…
export LAKEHOUSE_TOKEN="<personal access token>"
hql run load.hql
hql run report.hql
```

This path is the same protocol and the same code as the local one, but it
has not been run against a Databricks workspace; the cases here are checked
against the open-source stack only.

### From a subject to a lakehouse

[`nats-lakehouse/`](nats-lakehouse/) is one pipeline in three programs:

```text
raw-events.json
      │  produce-raw.hql        ingestion: each raw event one message
      ▼
 orders.raw  (NATS subject, stream ORDERS)
      │  ingest.hql             streaming: tap | validate | fork
      ├──ok───▶ orders_silver     (Delta table, appended as rows arrive)
      └──err──▶ orders.rejected   (NATS subject: the message and the rules it broke)

 orders_silver
      │  revenue.hql            transformation: filter | group | map
      ▼
 customer_revenue  (Delta table, replaced in one commit)
```

`ingest.hql` is the quarantine above with other endpoints: the clean side is
a Delta table and the rejected side a dead-letter subject, which a later
program taps as any other stream. `revenue.hql` reads the silver table whole
and writes the report whole. The two share nothing but the table between
them.

```hql
tap("orders_raw")
| validate(EventData)
| fork {
    silver   = oks()  | map(e => Event(…))    | sink("orders_silver"),
    rejected = errs() | map(e => Rejected(…)) | sink("orders_rejected"),
}
```

A `sink` into a Delta table writes its rows in statements of up to 500, each
one commit to the table's log, and one more when the stream ends.

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

The NATS-lakehouse case by hand, with two one-shot containers creating the
stream and the bucket:

```sh
cd nats-lakehouse
docker compose up -d --wait nats minio
docker compose run --rm streams
docker compose run --rm buckets
docker compose up -d --wait spark
export NATS_URL=nats://localhost:54222
export LAKEHOUSE_URL=http://localhost:50001/cliservice
hql run produce-raw.hql
hql run ingest.hql
hql run revenue.hql
hql run silver.hql
hql run gold.hql
hql run rejected.hql
docker compose down -v
```
