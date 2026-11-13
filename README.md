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
| [`nats/`](nats/) | NATS 2.11 with JetStream | Publish the mock events to a subject, one message each, then read the subject back from its stream: by id, by a transport written in the program, and through a durable consumer that remembers where the last read ended |
| [`nats-core/`](nats-core/) | NATS 2.11 without JetStream | A subscriber on a wildcard subject, started first, given the mock events a publisher sends to a subject per kind of event |
| [`lakehouse/`](lakehouse/) | Spark 3.5, Delta Lake 3.3, MinIO | Write the mock events to a Delta table, then read it back as a report per customer |
| [`nats-lakehouse/`](nats-lakehouse/) | all of the above | Raw messages on a subject routed into a silver Delta table or a dead-letter subject, then the silver table totalled into a gold Delta table |
| [`ledger/`](ledger/) | PostgreSQL 17 | Two accounts and a transfers table; a transfer of 100 as one transaction, twice committed and once rolled back on the sender's balance, then the ledger read back |
| [`crypto/`](crypto/) | none | A release folder listed into a manifest of SHA-256 digests, the manifest signed with an Ed25519 key, the folder, an altered copy and a forged manifest verified against it, and webhook deliveries kept one per body by fingerprint |

## Running

You need Docker with Compose, and an `hql` binary built from the sibling
`hql` repository (`cargo build` there) or on the `PATH`; set `HQL` to use
another one.

```sh
./run-all.sh            # every case
./kafka/run.sh          # one case
```

Each case starts its containers, runs its programs, and removes the
containers and their volumes when it ends. A step that fails prints the
case, the step, the command, hql's error output and a diff of the actual
output against the expected file.

CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) builds hql from
its `main`, or from any ref given to a manual run, and runs `postgres`,
`ledger` and `crypto`. hql runs the full `./run-all.sh` by hand before its
own releases, as a check against real services. The host ports are 59092 for
Kafka, 55432 for PostgreSQL, 54222 for NATS with JetStream, 54223 for core
NATS and 50001 for the Spark SQL endpoint.

The cases follow hql's latest `main`; hql-demo has no releases or
versions of its own. The first lakehouse run builds an image of Spark with
Delta Lake and the S3 connector; the build downloads about 300 MB of jars,
once.

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

NATS and a lakehouse sit on the same two sides of that line. NATS is two
kinds, each with a module of its own:

| Kind | Module | A read is given | A write is confirmed |
| --- | --- | --- | --- |
| `nats` | `io.msg.nats` | what is published while it is subscribed | by nothing |
| `nats_jetstream` | `io.msg.nats_jetstream` | what the stream keeps, from where the read says | by the stream, which stored it |

Both are read by `tap` and written by `sink`. A lakehouse table ends:
`kind = "spark"` is read by `source` and written by `target` or `sink`.

```toml
[endpoint.orders_raw]
kind = "nats_jetstream"
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

### A core subject

Core NATS keeps nothing, so a reader must be subscribed before a writer
publishes. [`nats-core/run.sh`](nats-core/run.sh) starts
[`subscribe.hql`](nats-core/subscribe.hql) in the background on the
wildcard `orders.>`, then runs [`publish.hql`](nats-core/publish.hql), which
sends each event to `orders.<kind>` through the constructor of
`io.msg.nats`:

```hql
import io.msg.nats

subject = (kind: String) => nats("orders." + kind, url_env = "NATS_URL")
for_kind("order_placed") | sink(subject("order_placed"))
```

The subscriber ends once the subjects have been quiet for `idle_ms`, and
what it printed is compared with what is expected.

### A position the server keeps

A stream stores messages. A consumer is the server's record of how far one
reader has come in it, and `consumer = "billing"` names a durable one: the
first read creates it, and every later read starts after the last message
the one before acknowledged.

```toml
[endpoint.billing]
kind = "nats_jetstream"
url_env = "NATS_URL"
stream = "EVENTS"
subject = "events.orders"
consumer = "billing"
idle_ms = 2000
```

[`nats/run.sh`](nats/run.sh) runs [`nats/resume.hql`](nats/resume.hql)
twice: the first run prints every event's id and the second prints nothing.
A message is acknowledged once the program asks for the one after it, so a
run that fails or stops early is given its last message again.

### A subject without configuration

The `nats_jetstream` kind is also the transport `NatsJetStream` of the
module `io.msg.nats_jetstream`, whose constructor takes the kind's keys.
[`nats/by-constructor.hql`](nats/by-constructor.hql) reads the subject with
no endpoint in `hql.toml`:

```hql
import io.msg.nats_jetstream

orders = nats_jetstream("events.orders", stream = "EVENTS", url_env = "NATS_URL", idle_ms = 2000)
tap(orders) | filter(e => e.kind == "order_placed")
```

A constructed transport has no schema boundary, so each message is read as
`Data`.

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

## A transfer as one transaction

[`ledger/transfer.hql`](ledger/transfer.hql) moves 100 from one account to
another as one transaction over two PostgreSQL tables
([HQL-0051](https://github.com/ewiger/hql/blob/main/doc/proposals/HQL-0051/README.md)):
the two accounts and the transfers table are the participants of one
`with transaction` scope, so its two `update`s and its `insert` hold or
fail together. The block reads the sender's balance through the scope's
own connection, so the row inserted after the updates sees them. A balance
below the amount rolls the attempt back by the program's own rule,
`tx.rollback("insufficient balance") given sender.balance < amount`, and
the scope's value says so as data, which the program matches on. Each
`update` is bound so its row count is read, and a debit or a credit that
matches no account rolls the transfer back rather than commit half of it.
A transfer's id is one more than the transfers made so far, counted in the
same attempt. Under `isolation = Serializable` a concurrent transfer that
conflicts is retried, up to the three attempts the scope names.
[`ledger/report.hql`](ledger/report.hql) reads the balances and the
transfers back; a `NUMERIC` column keeps its digits.

The case then races: [`ledger/seed-race.hql`](ledger/seed-race.hql) gives
the sender 150, and `run.sh` starts two transfers of 100 at once. Exactly
one commits; the other retries, reads the new balance and rolls back (or
ends `conflict` if its attempts run out), and no balance goes negative.

## A signed release

The `crypto/` case needs no service. It uses `io.fs`, `io.env`,
`crypto.digest`, `encoding` and the `crypto` module's signatures.

`manifest.hql` walks a release folder with `io.fs` and writes one JSON line
per file: its path within the folder, its size and the SHA-256 of its text.
The folder is `release/`, or the one `--arg dir=…` names:

```hql
root = env.arg("dir") | unwrap_or("release")

fs.folder(root).walk()
| filter(e => e.kind == "file")
| map(e => Item(
    path = e.path.text[size(root) + 1:],
    size = e.size | unwrap_or(0),
    sha256 = source(file(e.path), Text) | map(t => t.digest(Sha256)) | first | unwrap_or("")))
```

`sign.hql` signs the manifest's text with an Ed25519 private key, a detached
signature written in base64 beside the thumbprint of the key that verifies
it. The key in `keys/` is the published test key 1 of RFC 8032, never a key
to trust; `run.sh` sets its mode to `0600`, as `hql` requires of a private
key file.

`verify.hql` checks the signature with the public key first, then each file
of the manifest against the folder: `unchanged`, `changed` or `missing`.
`run.sh` verifies the release itself, then a copy with one file altered and
one removed, where the signature holds and the two files are reported, then
a manifest changed after it was signed, where the signature fails:

```json
{"files":[{"path":"VERSION","status":"unchanged"},{"path":"docs/NOTES.md","status":"unchanged"},{"path":"settings.toml","status":"missing"},{"path":"totals.csv","status":"changed"}],"signature":"valid"}
```

`fingerprints.hql` reads webhook deliveries that carry no id. A body sent
twice arrives with its keys in another order or with `42.00` for `42`, and
the fingerprint of a `Data` tree, the SHA-256 of its canonical JSON, is the
same for both: grouped by it, the first delivery of each body is kept, with
its number of copies and its fingerprint in hex and in base64.

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
