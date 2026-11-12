// Kafka to Postgres with a quarantine: every message of the topic
// `order_events_raw` that is an `Event` inserted into the table
// `order_clean`, and every message that is not inserted into the table
// `order_quarantine` with the reasons, as it arrives, without stopping.
//
// `tap("order_events_raw")` is a `Stream<Data>`, so no message fails to
// decode. `validate(EventData)` reads each as a `Result<EventData, Invalid>`:
// the view, or the message as it arrived and every violation at once.
// `fork` routes each result to one of two sinks in source order. The
// contract's rules are the quarantine's policy, and the pipeline's shape is
// what happens to a message that breaks one.
//
// `EventData` is an open view over the message; a table is written from a
// closed record, so an accepted view is read into an `Event` first.

type EventData : DataContract = {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String

    require amount >= 0 as non_negative
    require ["order_placed", "order_shipped", "payment_failed"] | contains(kind) as known_kind
}

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

type Rejected {
    id      : Int
    message : Data
    rules   : List<String>
}

tap("order_events_raw")
| validate(EventData)
| fork {
    clean =
        oks()
        | map(e => Event(id = e.id, kind = e.kind, customer = e.customer, amount = e.amount, at = e.at))
        | sink("order_clean"),
    quarantine =
        errs()
        | map(e => Rejected(
            id = match e.value.id { some(Int n) => n, _ => 0 },
            message = e.value,
            rules = e.violations | map(v => v.rule)))
        | sink("order_quarantine"),
}
