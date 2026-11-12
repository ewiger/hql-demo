// Streaming: every message of the subject `orders.raw` that is an `Event`
// appended to the Delta table `orders_silver`, and every message that is
// not published to the dead-letter subject `orders.rejected` with the
// rules it broke, as it arrives, without stopping.
//
// `tap("orders_raw")` is a `Stream<Data>`, so no message fails to decode.
// `validate(EventData)` reads each as a `Result<EventData, Invalid>`: the
// view, or the message as it arrived and every violation at once. `fork`
// routes each result to one of two sinks in source order.
//
// `EventData` is an open view over the message; a table is written from a
// closed record, so an accepted view is read into an `Event` first. The
// rows reach the table in statements of up to 500, each one commit to the
// Delta log.

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

tap("orders_raw")
| validate(EventData)
| fork {
    silver =
        oks()
        | map(e => Event(id = e.id, kind = e.kind, customer = e.customer, amount = e.amount, at = e.at))
        | sink("orders_silver"),
    rejected =
        errs()
        | map(e => Rejected(
            id = match e.value.id { some(Int n) => n, _ => 0 },
            message = e.value,
            rules = e.violations | map(v => v.rule)))
        | sink("orders_rejected"),
}
