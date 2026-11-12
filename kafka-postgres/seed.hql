// Seed the table `orders` with the mock events from a JSON file.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

events : Seq<Event> = source("mock_events")
events | target("orders")
