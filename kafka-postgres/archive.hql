// The table `order_archive` after the round trip: every event, with the
// digits of each amount as the JSON file wrote them.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

archive : Seq<Event> = source("order_archive")
archive
