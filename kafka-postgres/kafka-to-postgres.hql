// Kafka to Postgres: every message of the topic `order_events` inserted
// into the table `order_archive`, one row per message, as it arrives.
//
// A topic does not end, so `tap` reads it as a `Stream<Event>`, and
// `sink` writes each row as the stream gives it; `target` would wait for
// a whole value the stream never completes. The stream ends here once the
// topic has been idle for `idle_ms`.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

events : Stream<Event> = tap("order_events")
events | sink("order_archive")
