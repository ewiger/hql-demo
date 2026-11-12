// The table `order_clean` after the quarantine run: every message that
// was an `Event`, and nothing else.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

clean : Seq<Event> = source("order_clean")
clean
