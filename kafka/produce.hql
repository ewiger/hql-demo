// Read the mock events from a JSON file and write each to the Kafka topic
// `events` as one message.
//
// `source` reads the file whole, as a `Seq<Event>`: a file ends. `sink`
// writes one message per element, in order.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

events : Seq<Event> = source("mock_events")
events | sink("events")
