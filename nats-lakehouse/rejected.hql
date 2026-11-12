// The dead-letter subject `orders.rejected` after the ingest: each message
// that was not an `Event`, as it arrived, with the rule each one broke.
// The message is the tree the producer sent, so it can be repaired and
// published again.

type Rejected {
    id      : Int
    message : Data
    rules   : List<String>
}

rejected : Stream<Rejected> = tap("orders_rejected")
rejected
