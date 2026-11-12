// The Delta table `orders_silver` after the ingest: every message that
// was an `Event`, and nothing else.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

silver : Seq<Event> = source("orders_silver")
silver
