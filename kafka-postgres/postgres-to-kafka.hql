// Postgres to Kafka: every row of the table `orders` written to the topic
// `order_events`, one message per row.
//
// A table ends, so `source` reads it whole, as a `Seq<Event>`; `sink`
// writes each row as one JSON message, in the table's `order`.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

orders : Seq<Event> = source("orders")
orders | sink("order_events")
