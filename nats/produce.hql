// Read the mock events from a JSON file and publish each to the NATS
// subject `events.orders` as one message.
//
// `source` reads the file whole, as a `Seq<Event>`: a file ends. `sink`
// publishes one message per element, in order, and each is written once
// the stream `EVENTS` acknowledges it.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

events : Seq<Event> = source("mock_events")
events | sink("events")
